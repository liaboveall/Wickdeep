class_name Granny
extends RefCounted
## Granny the merchant: what she says back when the player talks at her stall.
## With a model configured she improvises (within Haggle's limits); otherwise she is scripted.

const HISTORY_MESSAGES := 8
const MAX_TOKENS := 260


static func greeting() -> String:
	return TextUtil.pick(GameText.GRANNY_GREET)


## True when the next line will go to the model (the shop shows a "thinking" indicator).
static func will_think() -> bool:
	return Haggle.can_talk() and AI.available()


## Say `text` to Granny. `option_id` is the quick reply it came from ("" for free text) and
## picks the scripted outcome when no model is available. `done` receives a Haggle.Turn.
static func hear(text: String, option_id: String, done: Callable) -> void:
	if not Haggle.can_talk():
		done.call(Haggle.tired())
		return
	if not AI.available():
		done.call(Haggle.scripted(option_id))
		return
	var visit := Run.camp
	visit.haggles_used += 1
	visit.granny_chat.append(Dialogue.user(text))
	var on_reply := func(res: Dictionary) -> void:
		_on_reply(res, visit, done)
	AI.ask(GameText.granny_system() + "\n\n" + context(), Dialogue.recent(visit.granny_chat, HISTORY_MESSAGES),
		on_reply, MAX_TOKENS)


static func _on_reply(res: Dictionary, visit: CampVisit, done: Callable) -> void:
	if visit != Run.camp:
		return   # the player has moved on; this answer belongs to a visit that is over
	var turn: Haggle.Turn
	if res.ok:
		turn = Haggle.from_model(res.data)
		visit.granny_chat.append(Dialogue.assistant(turn.reply))
	else:
		# hand the line back and settle it by the scripted rules instead
		visit.granny_chat.pop_back()
		visit.haggles_used -= 1
		turn = Haggle.scripted("haggle")
		turn.note = "（AI 暂时没有回应：%s，改用老规矩）" % res.error
	if done.is_valid():
		done.call(turn)


## What Granny is told about the stall and the customer before each line.
static func context() -> String:
	var visit := Run.camp
	var s := "摊位情况：%s。守灯人有 %d 余烬，生命 %d/%d。当前价格倍率 %.2f，这次光顾他还能再说 %d 句。你对他的好感：%d（-10 到 10）。" % [
		Shop.describe_stock(), Run.embers, Run.hp, Run.max_hp, visit.price_mult, Haggle.lines_left(),
		SaveData.granny_affinity]
	if visit.gift_given:
		s += "这次已经送过灯油了，不能再送。"
	if not SaveData.granny_memory.is_empty():
		s += "\n你记得关于他的事：" + "；".join(SaveData.granny_memory)
	return s
