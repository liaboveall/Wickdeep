extends Node
## DeepSeek (OpenAI-compatible) chat client.
## Requests ask for JSON output and, on DeepSeek, turn thinking off so replies come back fast.
## Every caller has a scripted fallback, so the game never depends on the network.
##
## All results have the same shape: {"ok": bool, "data": Dictionary, "error": String}.

signal busy_changed(busy: bool)

const MAX_ATTEMPTS := 2
const TEMPERATURE := 1.1

## HTTP status -> [message, retrying is pointless]
const HTTP_ERRORS := {
	401: ["API Key 无效或没有权限（401）", true],
	403: ["API Key 无效或没有权限（403）", true],
	402: ["账户余额不足（402）", true],
	404: ["接口地址或模型名不对（404）", true],
	429: ["请求太频繁（429）", false],
}

## HTTPRequest result -> [message, retrying is pointless]
## A timeout is not retried: the player has already waited the whole timeout once.
const TRANSPORT_ERRORS := {
	HTTPRequest.RESULT_TIMEOUT: ["请求超时", true],
	HTTPRequest.RESULT_CANT_RESOLVE: ["连接不上接口地址", false],
	HTTPRequest.RESULT_CANT_CONNECT: ["连接不上接口地址", false],
	HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: ["TLS 握手失败", false],
}

var busy := 0
var last_error := ""
var last_latency := 0.0


func _ready() -> void:
	# Requests are made from menus that pause the game; they must keep running while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS


func available() -> bool:
	return Settings.ai_available()


## Callback style for UI: the coroutine lives here (never freed); `cb` is skipped if the menu or
## scene that asked was closed meanwhile.
func ask(system_prompt: String, messages: Array, cb: Callable, max_tokens := 320, timeout := 18.0) -> void:
	var res: Dictionary = await chat_json(system_prompt, messages, max_tokens, timeout)
	if cb.is_valid():
		cb.call(res)


func ask_test(cb: Callable) -> void:
	var res: Dictionary = await test_connection()
	if cb.is_valid():
		cb.call(res)


## Send a chat request and parse the reply as a JSON object.
func chat_json(system_prompt: String, messages: Array, max_tokens := 320, timeout := 18.0) -> Dictionary:
	if not available():
		return _failure("未配置 API Key")
	busy += 1
	busy_changed.emit(true)
	var res := {}
	for attempt in MAX_ATTEMPTS:
		res = await _request(system_prompt, messages, max_tokens, timeout)
		if res.ok or res.get("fatal", false):
			break
	busy -= 1
	busy_changed.emit(busy > 0)
	if not res.ok:
		last_error = res.error
		push_warning("AI request failed: %s" % res.error)
	return res


## Small request used by the settings screen's "test connection" button.
func test_connection() -> Dictionary:
	var started := Time.get_ticks_msec()
	var res := await chat_json("你是连通性测试。只输出一个 json 对象。", [
		{"role": "user", "content": "请只回复 {\"ok\": true, \"msg\": \"一句不超过10个字的问候\"}"}
	], 60, 15.0)
	res["latency"] = (Time.get_ticks_msec() - started) / 1000.0
	return res


func endpoint() -> String:
	var base := Settings.base_url.strip_edges().trim_suffix("/")
	if base.ends_with("/chat/completions"):
		return base
	return base + "/chat/completions"


func _request(system_prompt: String, messages: Array, max_tokens: int, timeout: float) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = timeout
	http.use_threads = true
	add_child(http)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + Settings.effective_api_key(),
	])
	var started := Time.get_ticks_msec()
	var err := http.request(endpoint(), headers, HTTPClient.METHOD_POST,
		JSON.stringify(_body(system_prompt, messages, max_tokens)))
	if err != OK:
		http.queue_free()
		return _failure("无法发起请求（%d）" % err)
	var response: Array = await http.request_completed
	http.queue_free()
	last_latency = (Time.get_ticks_msec() - started) / 1000.0
	return _read_response(response[0], response[1], response[3])


func _body(system_prompt: String, messages: Array, max_tokens: int) -> Dictionary:
	var all: Array = [{"role": "system", "content": system_prompt}]
	all.append_array(messages)
	var body := {
		"model": Settings.model,
		"messages": all,
		"response_format": {"type": "json_object"},
		"max_tokens": max_tokens,
		"temperature": TEMPERATURE,
		"stream": false,
	}
	if "deepseek" in Settings.base_url:
		body["thinking"] = {"type": "disabled"}
	return body


static func _read_response(result: int, code: int, raw: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		var transport: Array = TRANSPORT_ERRORS.get(result, ["网络错误（%d）" % result, false])
		return _failure(transport[0], transport[1])
	if HTTP_ERRORS.has(code):
		return _failure(HTTP_ERRORS[code][0], HTTP_ERRORS[code][1])
	if code != 200:
		return _failure("接口返回 %d" % code)
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(raw.get_string_from_utf8()) == OK else null
	if not parsed is Dictionary or not parsed.get("choices") is Array or parsed.choices.is_empty():
		return _failure("返回格式不对")
	var choice: Variant = parsed.choices[0]
	var message: Variant = choice.get("message") if choice is Dictionary else null
	var content := str(message.get("content", "")) if message is Dictionary else ""
	var data := parse_json_object(content)
	if data.is_empty():
		return _failure("模型没有返回 JSON")
	return {"ok": true, "data": data, "error": ""}


static func _failure(error: String, fatal := false) -> Dictionary:
	return {"ok": false, "data": {}, "error": error, "fatal": fatal}


## Extract the first JSON object from a model reply (tolerates code fences and stray text).
static func parse_json_object(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t.begins_with("```"):
		t = t.trim_prefix("```json").trim_prefix("```").trim_suffix("```").strip_edges()
	var a := t.find("{")
	var b := t.rfind("}")
	if a < 0 or b <= a:
		return {}
	var json := JSON.new()
	if json.parse(t.substr(a, b - a + 1)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}
