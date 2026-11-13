class_name Wick
extends RefCounted
## Wick the lantern spirit: greets the player at the camp, chats, and writes the epitaph when a
## run ends. Every line has a scripted fallback, so the game never depends on the network.

const HISTORY_MESSAGES := 10
const TITLE_LENGTH := 12
const REPLY_UNUSABLE := "回复格式不对"

const ARRIVAL_ASK := "（守灯人刚走进营地，坐到篝火边。根据他刚通过的这一层的表现，主动说一句开场白，可以夸、可以损、可以提醒。）"
const ARRIVAL_FORMAT := "回复格式：{\"reply\": \"你的开场白\"}"
const CHAT_FORMAT := "回复格式：{\"reply\": \"你的回答\", \"mood\": \"happy|teasing|worried|proud|serious\"}"
const EPITAPH_FORMAT := "回复格式：{\"title\": \"4到8个字的称号\", \"epitaph\": \"不超过80个汉字\", \"memory\": \"不超过25个汉字\"}"
const EPITAPH_ASK_WIN := "（守灯人击败了熄灯者，圣火重燃。为这次冒险写一段结语：给他一个称号，写一段不超过80字的结语；再用一句话记下这次冒险里你最想记住的事，下次见面时会提起。）"
const EPITAPH_ASK_DEATH := "（守灯人倒在了第%d层，击倒他的是%s。为他写一段墓志铭：一个称号，一段不超过80字的墓志铭，可以带点灯芯式的幽默但要真诚；再用一句话记下这次冒险里你最想记住的事，下次见面时会提起。）"


static func _system(format: String) -> String:
	return GameText.wick_system() + "\n\n" + context() + "\n\n" + format


# ------------------------------------------------------------------ arriving at the camp
## True while the greeting for this visit still has to come from the model.
static func arrival_pending() -> bool:
	return Run.camp.wick_arrival == "" and AI.available()


## Wick's comment on the depth just cleared. Written once per visit, then repeated.
## `done` receives (line: String, fresh: bool); fresh is false when it was already written.
static func arrival(done: Callable) -> void:
	var visit := Run.camp
	if visit.wick_arrival != "":
		done.call(visit.wick_arrival, false)
		return
	if not AI.available():
		visit.wick_arrival = scripted_arrival()
		done.call(visit.wick_arrival, true)
		return
	var on_reply := func(res: Dictionary) -> void:
		var line := ""
		if res.ok:
			line = TextUtil.clean(Dialogue.text_field(res.data, "reply"))
		visit.wick_arrival = line if line != "" else scripted_arrival()
		if done.is_valid():
			done.call(visit.wick_arrival, true)
	AI.ask(_system(ARRIVAL_FORMAT), [Dialogue.user(ARRIVAL_ASK)], on_reply, 160, 14.0)


static func scripted_arrival() -> String:
	var mood := "normal"
	var last := Run.last_depth()
	if not last.is_empty():
		if last.damage_taken == 0:
			mood = "clean"
		elif Run.hp <= 2:
			mood = "hurt"
		elif Run.embers >= 90:
			mood = "rich"
	return TextUtil.pick(GameText.WICK_ARRIVE[mood])


# ------------------------------------------------------------------ fireside chat
## Say something to Wick. `done` receives (reply: String, note: String); note is a status line
## for the chat panel, "" when there is nothing to report.
static func hear(text: String, done: Callable) -> void:
	if not AI.available():
		done.call(scripted_reply(text), "")
		return
	var chat := Run.wick_chat
	chat.append(Dialogue.user(text))
	var on_reply := func(res: Dictionary) -> void:
		var line := chat_reply(res, text)
		chat.append(Dialogue.assistant(line[0]))
		if done.is_valid():
			done.call(line[0], line[1])
	AI.ask(_system(CHAT_FORMAT), Dialogue.recent(chat, HISTORY_MESSAGES), on_reply, 220)


## What Wick says for one result from the model: [reply, note]. A failed request, or an answer
## without a usable line in it, becomes a scripted reply plus a note saying why.
static func chat_reply(res: Dictionary, asked: String) -> Array[String]:
	var reply := ""
	if res.ok:
		reply = TextUtil.clean(Dialogue.text_field(res.data, "reply"))
	if reply != "":
		return [reply, ""]
	var reason: String = REPLY_UNUSABLE if res.ok else res.error
	return [scripted_reply(asked), "（AI 暂时没有回应：%s）" % reason]


static func scripted_reply(text: String) -> String:
	if "建议" in text or "注意" in text or "怎么打" in text:
		return TextUtil.pick(GameText.WICK_TIPS)
	if "怎么样" in text:
		return TextUtil.pick(GameText.WICK_ARRIVE.normal)
	return TextUtil.pick(GameText.WICK_SMALL_TALK + GameText.WICK_TIPS)


# ------------------------------------------------------------------ end of a run
## Write the epitaph (or the victory epilogue), keep it in the save together with one memory Wick
## brings up next run, then hand (title: String, text: String) to `done`.
static func write_epitaph(victory: bool, done: Callable) -> void:
	var depth := Run.depth
	if not AI.available():
		_keep_epitaph({}, victory, depth, done)
		return
	var ask := EPITAPH_ASK_WIN
	if not victory:
		ask = EPITAPH_ASK_DEATH % [depth, Bestiary.display_name(Run.killer, "黑暗")]
	var on_reply := func(res: Dictionary) -> void:
		_keep_epitaph(res.data if res.ok else {}, victory, depth, done)
	AI.ask(_system(EPITAPH_FORMAT), [Dialogue.user(ask)], on_reply, 260, 16.0)


static func _keep_epitaph(data: Dictionary, victory: bool, depth: int, done: Callable) -> void:
	var title := Dialogue.text_field(data, "title").left(TITLE_LENGTH)
	var text := TextUtil.clean(Dialogue.text_field(data, "epitaph"))
	var memory := Dialogue.text_field(data, "memory")
	if title == "" or text == "":
		var scripted: Array = TextUtil.pick_item(GameText.WICK_EPITAPH_WIN if victory else GameText.WICK_EPITAPH_DEATH)
		title = scripted[0]
		text = scripted[1] % depth if "%d" in scripted[1] else scripted[1]
		memory = "上次你真的点燃了圣火" if victory else "上次你在第%d层倒下了" % depth
	SaveData.remember(SaveData.wick_memory, memory)
	SaveData.add_epitaph(title, text, depth, victory)
	SaveData.save_data()
	if done.is_valid():
		done.call(title, text)


# ------------------------------------------------------------------ what Wick knows
static func context() -> String:
	var s := "当前状态：已到达第 %d 层的营地，生命 %d/%d，余烬 %d，遗物：%s，本局累计击败 %d 个敌人。" % [
		Run.depth, Run.hp, Run.max_hp, Run.embers, Relics.names(Run.relics), Run.kills]
	var last := Run.last_depth()
	if not last.is_empty():
		s += "\n刚通过的第 %d 层：击败 %d 个敌人，受伤 %d 点，用时 %d 秒" % [
			last.depth, last.kills, last.damage_taken, last.time]
		if last.worst_enemy != "":
			s += "，伤他最多的是%s" % Bestiary.display_name(last.worst_enemy, last.worst_enemy)
		s += "。"
	if not SaveData.wick_memory.is_empty():
		s += "\n你记得之前几次冒险的事：" + "；".join(SaveData.wick_memory)
	s += "\n这是守灯人的第 %d 次下深渊（已通关 %d 次）。" % [SaveData.runs, SaveData.wins]
	return s
