extends "res://tests/test_suite.gd"
## Wick and Granny without a network: reply parsing, the scripted fallbacks, and how the AI
## client turns HTTP responses into results.


func before_each() -> void:
	fresh_run()


func _response(code: int, body: String, result := HTTPRequest.RESULT_SUCCESS) -> Dictionary:
	return AI._read_response(result, code, body.to_utf8_buffer())


func test_parse_json_object() -> void:
	var cases := {
		"{\"reply\": \"你好\"}": "你好",
		"```json\n{\"reply\": \"a\"}\n```": "a",
		"好的：{\"reply\": \"b\", \"mood\": \"happy\"} 以上": "b",
	}
	for text: String in cases:
		equal(AI.parse_json_object(text).get("reply", ""), cases[text], "parse: " + text)
	check(AI.parse_json_object("没有 JSON").is_empty(), "no JSON -> empty")
	check(AI.parse_json_object("{坏的}").is_empty(), "broken JSON -> empty")
	check(AI.parse_json_object("[1, 2]").is_empty(), "an array is not an object")


func test_http_responses() -> void:
	var ok := _response(200, JSON.stringify({"choices": [{"message": {"content": "{\"reply\": \"嗯\"}"}}]}))
	check(ok.ok and ok.data.reply == "嗯", "a normal completion")
	for code: int in [401, 402, 403, 404]:
		var res := _response(code, "{}")
		check(not res.ok and res.fatal, "%d fails and is not retried" % code)
	var busy := _response(429, "{}")
	check(not busy.ok and not busy.fatal, "429 fails but may be retried")
	check(not _response(500, "oops").ok, "server error")
	check(not _response(200, "not json").ok, "200 with a non-JSON body")
	check(not _response(200, "{\"choices\": []}").ok, "200 without choices")
	check(not _response(200, JSON.stringify({"choices": [{"message": {"content": "just text"}}]})).ok,
		"the model answered without JSON")
	check(not _response(200, JSON.stringify({"choices": ["what"]})).ok, "malformed choice")
	var timeout := _response(0, "", HTTPRequest.RESULT_TIMEOUT)
	check(not timeout.ok and timeout.error == "请求超时", "timeout is reported as such")
	check(timeout.fatal, "and not retried: the player has waited long enough")
	var refused := _response(0, "", HTTPRequest.RESULT_CANT_CONNECT)
	check(not refused.ok and not refused.fatal, "a refused connection may be retried")
	var odd := _response(0, "", HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED)
	check(not odd.ok and not odd.fatal and odd.error != "", "any other transport error still has a message")


func test_endpoint() -> void:
	var saved := Settings.base_url
	Settings.base_url = "https://api.deepseek.com"
	equal(AI.endpoint(), "https://api.deepseek.com/chat/completions", "path appended")
	Settings.base_url = "https://example.test/v1/"
	equal(AI.endpoint(), "https://example.test/v1/chat/completions", "trailing slash handled")
	Settings.base_url = "https://example.test/v1/chat/completions"
	equal(AI.endpoint(), "https://example.test/v1/chat/completions", "full URL kept")
	Settings.base_url = saved


func test_dialogue_helpers() -> void:
	equal(Dialogue.spoken(Dialogue.user("你好")), "你好", "user message")
	equal(Dialogue.spoken(Dialogue.assistant("嘿嘿")), "嘿嘿", "assistant message unwrapped")
	check(Dialogue.is_user(Dialogue.user("x")) and not Dialogue.is_user(Dialogue.assistant("x")), "roles")
	equal(Dialogue.recent([1, 2, 3, 4, 5], 2), [4, 5], "recent messages")
	equal(Dialogue.recent([1], 10), [1], "short history kept whole")
	equal(Dialogue.text_field({"a": "  x "}, "a"), "x", "text trimmed")
	equal(Dialogue.text_field({"a": null}, "a"), "", "null is not text")
	equal(Dialogue.text_field({"a": 5}, "a"), "", "a number is not text")
	equal(Dialogue.text_field({}, "a"), "", "missing field")


func test_wick_arrival_is_written_once() -> void:
	var lines := []
	check(not Wick.arrival_pending(), "nothing to wait for without a model")
	Wick.arrival(func(line: String, fresh: bool) -> void: lines.append([line, fresh]))
	Wick.arrival(func(line: String, fresh: bool) -> void: lines.append([line, fresh]))
	equal(lines.size(), 2, "answers at once")
	check(lines[0][0] != "" and lines[0][1], "first greeting is fresh")
	check(lines[1][0] == lines[0][0] and not lines[1][1], "then repeated, not rewritten")
	check(lines[0][0] in GameText.WICK_ARRIVE.normal, "nothing to comment on before the first depth")


func test_wick_arrival_reads_the_run() -> void:
	Run.finish_depth()
	check(Wick.scripted_arrival() in GameText.WICK_ARRIVE.clean, "untouched -> impressed")
	Run.take_damage(4, "bat")
	Run.finish_depth()
	check(Wick.scripted_arrival() in GameText.WICK_ARRIVE.hurt, "nearly dead -> worried")
	Run.heal(10)
	Run.take_damage(1, "bat")
	Run.add_embers(200)
	Run.finish_depth()
	check(Wick.scripted_arrival() in GameText.WICK_ARRIVE.rich, "rich -> teases about embers")


func test_wick_chat_fallback() -> void:
	var replies := []
	Wick.hear("下一层我该注意什么？", func(reply: String, note: String) -> void: replies.append([reply, note]))
	check(replies[0][0] in GameText.WICK_TIPS, "asked for advice -> a tip")
	equal(replies[0][1], "", "no status note")
	equal(Run.wick_chat.size(), 0, "scripted chat is not sent to a model later")
	check(Wick.scripted_reply("随便聊聊") != "", "small talk")
	check("本局累计击败" in Wick.context(), "context describes the run")


func test_wick_chat_reply_from_model() -> void:
	var good := Wick.chat_reply({"ok": true, "data": {"reply": " 嘿，守灯人。 "}, "error": ""}, "你好")
	equal(good[0], "嘿，守灯人。", "the model's line is used")
	equal(good[1], "", "nothing to report")
	var failed := Wick.chat_reply(AI._failure("请求超时"), "给我点建议")
	check(failed[0] in GameText.WICK_TIPS, "a failed request falls back to a scripted line")
	check("请求超时" in failed[1], "and the note says why")
	for data: Dictionary in [{}, {"reply": null}, {"reply": ["不是字符串"]}, {"reply": "   "}]:
		var unusable := Wick.chat_reply({"ok": true, "data": data, "error": ""}, "给我点建议")
		check(unusable[0] in GameText.WICK_TIPS, "an answer without a line falls back too: %s" % str(data))
		check(Wick.REPLY_UNUSABLE in unusable[1], "and the note gives a reason: %s" % str(data))


func test_epitaph_is_kept() -> void:
	Run.depth = 3
	Run.killer = "archer"
	var written := []
	Wick.write_epitaph(false, func(title: String, text: String) -> void: written.append([title, text]))
	equal(written.size(), 1, "written at once without a model")
	check(written[0][0] != "" and written[0][1] != "", "has title and text")
	check(not "%d" in written[0][1], "depth filled in")
	equal(SaveData.epitaphs.size(), 1, "kept in the profile")
	equal(SaveData.epitaphs[0].depth, 3, "with the depth")
	check("上次你在第3层倒下了" in SaveData.wick_memory, "Wick remembers how it ended")
	Wick.write_epitaph(true, func(_title: String, _text: String) -> void: pass)
	check(SaveData.epitaphs[1].won, "victory epilogue marked as won")
	for k in SaveData.EPITAPH_LIMIT + 5:
		SaveData.add_epitaph("t", "x", 1, false)
	equal(SaveData.epitaphs.size(), SaveData.EPITAPH_LIMIT, "old epitaphs drop off")
