class_name Haggle
extends RefCounted
## Rules of haggling with Granny. A language model may write her lines, but every number it
## returns is clamped here, so no amount of prompt injection can break the economy.

const MAX_LINES := 6          # things the player can say per visit
const STEP := 0.10            # most the price multiplier can move per line
const MIN_MULT := 0.70
const MAX_MULT := 1.30
const MAX_MOOD_STEP := 2
const GIFT_HEAL := 2


## What one line said to Granny led to. The shop screen turns this into text and sounds.
class Turn:
	var reply := ""
	var note := ""            # status line shown under the chat ("" = none)
	var price_change := 0     # -1 cheaper, +1 dearer, 0 unchanged
	var gift := false         # she handed over a bottle of oil
	var refused := false      # she is done talking for this visit; nothing changed


## Granny's opening price depends on how much she likes the player.
static func starting_mult(affinity: int) -> float:
	return clampf(1.0 - affinity * 0.01, 0.85, 1.15)


static func lines_left() -> int:
	return MAX_LINES - Run.camp.haggles_used


static func can_talk() -> bool:
	return lines_left() > 0


## The game, not the model, decides how far a price can move.
static func clamp_mult(current: float, wanted: float) -> float:
	if is_nan(wanted) or is_inf(wanted):
		wanted = current
	var next := clampf(wanted, current - STEP, current + STEP)
	return clampf(snappedf(next, 0.01), MIN_MULT, MAX_MULT)


## Model output is untrusted: accept numbers or numeric strings, otherwise use the fallback.
static func to_number(v: Variant, fallback: float) -> float:
	if v is float or v is int:
		return float(v)
	if v is String and (v as String).is_valid_float():
		return (v as String).to_float()
	return fallback


static func tired() -> Turn:
	var turn := Turn.new()
	turn.refused = true
	turn.reply = GameText.granny_line("tired")
	return turn


## Scripted outcome of a quick reply (GameText.GRANNY_OPTIONS), used when no model is available.
static func scripted(option_id: String) -> Turn:
	if not can_talk():
		return tired()
	var visit := Run.camp
	visit.haggles_used += 1
	var turn := Turn.new()
	var line := ""
	match option_id:
		"praise":
			if randf() < 0.6:
				turn.price_change = _move_price(visit.price_mult - 0.06)
				SaveData.shift_granny_affinity(1)
				line = "praise_ok"
			else:
				line = "praise_no"
		"story":
			if visit.story_told:
				line = "story_again"
			else:
				visit.story_told = true
				turn.price_change = _move_price(visit.price_mult - 0.08)
				SaveData.shift_granny_affinity(1)
				line = "story"
		"threat":
			turn.price_change = _move_price(visit.price_mult + 0.10)
			SaveData.shift_granny_affinity(-2)
			line = "threat"
		_:
			if randf() < 0.5:
				turn.price_change = _move_price(visit.price_mult - 0.07)
				line = "haggle_ok"
			else:
				turn.price_change = _move_price(visit.price_mult + 0.04)
				line = "haggle_no"
	turn.reply = GameText.granny_line(line)
	SaveData.save_data()
	return turn


## Apply a model reply {reply, mood_delta, price_multiplier, gift, memory} within the rules.
## The caller has already counted the line against the visit.
static func from_model(data: Dictionary) -> Turn:
	var visit := Run.camp
	var turn := Turn.new()
	turn.reply = TextUtil.clean(Dialogue.text_field(data, "reply"))
	if turn.reply == "":
		turn.reply = GameText.granny_line("silent")
	turn.price_change = _move_price(to_number(data.get("price_multiplier"), visit.price_mult))
	var mood := clampi(int(to_number(data.get("mood_delta"), 0.0)), -MAX_MOOD_STEP, MAX_MOOD_STEP)
	SaveData.shift_granny_affinity(mood)
	SaveData.remember(SaveData.granny_memory, Dialogue.text_field(data, "memory"))
	if Dialogue.text_field(data, "gift") == "oil" and not visit.gift_given:
		visit.gift_given = true
		turn.gift = true
		turn.note = "秤婆塞给你一瓶灯油（生命 +%d）" % GIFT_HEAL
		Run.heal(GIFT_HEAL)
	SaveData.save_data()
	return turn


static func _move_price(wanted: float) -> int:
	var visit := Run.camp
	var before := visit.price_mult
	visit.price_mult = clamp_mult(before, wanted)
	if visit.price_mult < before - 0.001:
		return -1
	if visit.price_mult > before + 0.001:
		return 1
	return 0
