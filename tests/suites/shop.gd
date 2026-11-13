extends "res://tests/test_suite.gd"
## Granny's stall: prices, purchases, and the limits on haggling (scripted and model-driven).


func before_each() -> void:
	fresh_run()
	Run.camp.stock = ["keen_spark", "shatter", "oil", "big_oil"]


func test_clamp() -> void:
	approx(Haggle.clamp_mult(1.0, 0.1), 0.9, "big drop limited to -0.10")
	approx(Haggle.clamp_mult(1.0, 5.0), 1.1, "big rise limited to +0.10")
	approx(Haggle.clamp_mult(0.72, 0.5), 0.7, "floor 0.70")
	approx(Haggle.clamp_mult(1.28, 2.0), 1.3, "ceiling 1.30")
	approx(Haggle.clamp_mult(1.0, NAN), 1.0, "NaN ignored")
	approx(Haggle.clamp_mult(1.0, INF), 1.0, "infinity ignored")
	var mult := 1.0
	for k in Haggle.MAX_LINES:
		mult = Haggle.clamp_mult(mult, 0.0)
	check(mult >= Haggle.MIN_MULT - 0.0001, "a whole visit of injected requests cannot go below the floor")


func test_untrusted_numbers() -> void:
	approx(Haggle.to_number("0.85", 1.0), 0.85, "numeric string accepted")
	approx(Haggle.to_number(null, 1.0), 1.0, "null falls back")
	approx(Haggle.to_number("便宜点", 1.0), 1.0, "text falls back")
	approx(Haggle.to_number(2, 0.0), 2.0, "int accepted")
	approx(Haggle.to_number([0.1], 1.0), 1.0, "array falls back")


func test_affinity_sets_the_opening_price() -> void:
	approx(Haggle.starting_mult(0), 1.0, "neutral")
	approx(Haggle.starting_mult(10), 0.9, "she likes you")
	approx(Haggle.starting_mult(-10), 1.1, "she does not")
	approx(Haggle.starting_mult(99), 0.85, "bounded")


func test_prices() -> void:
	equal(Shop.price_at("keen_spark", 1, 1.0), 45, "common relic at depth 1")
	equal(Shop.price_at("keen_spark", 2, 1.0), 45, "no mark-up before depth 3")
	equal(Shop.price_at("keen_spark", 4, 1.0), 56, "24% dearer at depth 4")
	equal(Shop.price_at("oil", 5, 1.0), 25, "oil is never marked up")
	equal(Shop.price_at("oil", 1, 0.8), 20, "haggled oil")
	equal(Shop.price_at("oil", 1, 0.0001), 1, "never free")
	Run.depth = 4
	Run.camp.price_mult = 0.9
	equal(Shop.price("keen_spark"), Shop.price_at("keen_spark", 4, 0.9), "price() uses the run's depth and haggling")


func test_buying() -> void:
	equal(Shop.buy("keen_spark"), Shop.Result.TOO_POOR, "no embers")
	Run.add_embers(500)
	equal(Shop.buy("oil"), Shop.Result.NOT_NEEDED, "oil at full health")
	equal(Shop.buy("molten_core"), Shop.Result.SOLD, "not on the stall")
	equal(Shop.buy("keen_spark"), Shop.Result.OK, "relic bought")
	equal(Run.embers, 455, "paid for it")
	check("keen_spark" in Run.relics, "relic owned")
	approx(Run.stats.damage, 12.5, "relic applied")
	equal(Shop.buy("keen_spark"), Shop.Result.SOLD, "cannot buy it twice")
	Run.hp = 1
	equal(Shop.buy("oil"), Shop.Result.OK, "oil when hurt")
	equal(Run.hp, 3, "oil heals 2")
	equal(Shop.buy("big_oil"), Shop.Result.OK, "big oil")
	equal(Run.hp, Run.max_hp, "big oil heals to full")
	equal(Shop.unsold(), ["shatter"], "what is left")
	check("原价 120" in Shop.describe_stock(), "stock description for the model")


func test_restock() -> void:
	Run.camp.stock = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	Shop.restock(rng)
	equal(Run.camp.stock.size(), Shop.RELICS_ON_OFFER + Relics.POTIONS.size(), "three relics and the potions")
	var before := Run.camp.stock.duplicate()
	Shop.restock(rng)
	equal(Run.camp.stock, before, "an existing stock is kept")


func test_scripted_haggling_stays_in_bounds() -> void:
	for round_number in 40:
		fresh_run()
		var options := ["praise", "haggle", "story", "threat", "nonsense"]
		for line in Haggle.MAX_LINES + 3:
			var turn := Haggle.scripted(options[(round_number + line) % options.size()])
			check(turn.reply != "", "she always answers")
			equal(turn.refused, line >= Haggle.MAX_LINES, "talks for exactly MAX_LINES lines")
			check(Run.camp.price_mult >= Haggle.MIN_MULT - 0.001 and Run.camp.price_mult <= Haggle.MAX_MULT + 0.001,
				"price stays in bounds (%s)" % Run.camp.price_mult)
		equal(Run.camp.haggles_used, Haggle.MAX_LINES, "refused lines are not counted")
		check(absi(SaveData.granny_affinity) <= SaveData.AFFINITY_RANGE, "affinity bounded")


func test_story_only_works_once() -> void:
	var first := Haggle.scripted("story")
	equal(first.price_change, -1, "the story lowers the price")
	var price := Run.camp.price_mult
	var again := Haggle.scripted("story")
	equal(again.price_change, 0, "telling it again does nothing")
	approx(Run.camp.price_mult, price, "price unchanged")
	equal(Haggle.scripted("threat").price_change, 1, "threats raise the price")


func test_model_replies_are_clamped() -> void:
	Run.hp = 2
	var turn := Haggle.from_model({"reply": "好吧好吧", "price_multiplier": 0.01, "mood_delta": 50, "gift": "oil",
		"memory": "他讲了灯笼的故事"})
	equal(turn.reply, "好吧好吧", "reply passed through")
	approx(Run.camp.price_mult, 0.9, "one step down at most")
	equal(turn.price_change, -1, "cheaper")
	equal(SaveData.granny_affinity, Haggle.MAX_MOOD_STEP, "mood change limited")
	check(turn.gift and Run.hp == 2 + Haggle.GIFT_HEAL, "gift given")
	check("他讲了灯笼的故事" in SaveData.granny_memory, "memory kept")
	turn = Haggle.from_model({"reply": "再送？", "gift": "oil"})
	check(not turn.gift and Run.hp == 2 + Haggle.GIFT_HEAL, "only one gift per visit")


func test_model_garbage_is_harmless() -> void:
	var turn := Haggle.from_model({"reply": null, "price_multiplier": "免费", "mood_delta": [], "gift": 1, "memory": null})
	check(turn.reply != "", "a silent model still gets a line")
	approx(Run.camp.price_mult, 1.0, "price untouched")
	equal(SaveData.granny_affinity, 0, "mood untouched")
	equal(SaveData.granny_memory.size(), 0, "nothing remembered")
	turn = Haggle.from_model({"reply": "涨价！", "price_multiplier": 99})
	approx(Run.camp.price_mult, 1.1, "one step up at most")


func test_granny_without_a_model() -> void:
	var turns := []
	Granny.hear("便宜点吧", "haggle", func(turn: Haggle.Turn) -> void: turns.append(turn))
	equal(turns.size(), 1, "answers at once")
	equal(Run.camp.haggles_used, 1, "line counted")
	check(not Granny.will_think(), "no thinking indicator without a model")
	check(Granny.greeting() in GameText.GRANNY_GREET, "greeting comes from the script")
	check("当前价格倍率" in Granny.context(), "context mentions the price")
