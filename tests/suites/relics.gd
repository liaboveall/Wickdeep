extends "res://tests/test_suite.gd"
## The relic catalogue and the stats it produces.


func test_base_stats() -> void:
	var base := Relics.compute([])
	approx(base.damage, 10.0, "base damage")
	approx(base.fire_interval, 0.25, "base fire interval")
	equal(base.projectiles, 1, "one bolt")
	equal(base.motes, 0, "no motes")


func test_stacking() -> void:
	var s := Relics.compute(["keen_spark", "keen_spark", "twin_wick", "quickburn"])
	approx(s.damage, 15.0, "two keen sparks add 50%")
	equal(s.projectiles, 2, "twin wick adds a bolt")
	check(s.fire_interval < 0.25, "quickburn fires faster")
	var greedy := Relics.compute(["greedy_lamp"])
	check(greedy.max_hp_bonus == -2 and greedy.ember_mult > 1.5, "greedy lamp trades health for embers")
	equal(Relics.compute(["motes"]).motes, 2, "the first mote relic brings two")
	equal(Relics.compute(["motes", "motes", "motes"]).motes, 4, "further ones add one each")


func test_pickup_order_does_not_matter() -> void:
	var a := Relics.compute(["molten_core", "keen_spark", "wildfire", "quickburn"])
	var b := Relics.compute(["quickburn", "wildfire", "keen_spark", "molten_core"])
	approx(a.damage, b.damage, "damage")
	approx(a.fire_interval, b.fire_interval, "fire interval")
	approx(a.damage, 10.0 * 1.25 * 1.6, "bonuses add, then multipliers multiply")


func test_every_relic_is_well_formed() -> void:
	var probe := PlayerStats.new()
	var icons: Dictionary = SpriteLib.manifest().icons.anims
	for id: String in Relics.DEFS:
		var def: Dictionary = Relics.DEFS[id]
		check(def.rarity in Relics.RARITY_WEIGHT, id + ": known rarity")
		check(int(def.max) >= 1, id + ": can be owned")
		check(def.name != "" and def.desc != "", id + ": has name and description")
		check(icons.has(id), id + ": has an icon")
		var effects := 0
		for op: String in ["add", "mul", "set"]:
			for key: String in def.get(op, {}):
				effects += 1
				check(probe.has_property(key), "%s: %s.%s is a PlayerStats field" % [id, op, key])
		check(effects > 0, id + ": does something")
	for id: String in Relics.POTIONS:
		check(icons.has(id), id + ": has an icon")
		check(int(Relics.POTIONS[id].heal) > 0, id + ": heals")


func test_every_relic_changes_the_stats() -> void:
	const Golden := preload("res://tests/golden.gd")
	var base := Golden.stats_dict(Relics.compute([]))
	for id: String in Relics.DEFS:
		check(Golden.stats_dict(Relics.compute([id])) != base, id + ": changes at least one stat")


func test_roll() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 200:
		var picks := Relics.roll(rng, [], 3)
		equal(picks.size(), 3, "roll returns 3")
		var distinct := {}
		for id in picks:
			distinct[id] = true
		equal(distinct.size(), 3, "roll returns distinct relics")
	for k in 50:
		check(not "twin_wick" in Relics.roll(rng, ["twin_wick", "twin_wick", "twin_wick"], 3), "maxed relic not offered")
		check(not "pierce" in Relics.roll(rng, [], 3, ["pierce"]), "excluded relic not offered")
	var everything := []
	for id: String in Relics.DEFS:
		for n in int(Relics.DEFS[id].max):
			everything.append(id)
	equal(Relics.roll(rng, everything, 3).size(), 0, "nothing left to offer")


func test_catalogue_helpers() -> void:
	equal(Relics.base_price("keen_spark"), 45, "common price")
	equal(Relics.base_price("shatter"), 120, "legendary price")
	equal(Relics.base_price("oil"), 25, "oil price")
	equal(Relics.names([]), "无", "no relics")
	equal(Relics.names(["twin_wick", "oil"]), "双芯、灯油", "names joined")
	equal(Relics.tally(["pierce", "motes", "pierce"]), [["pierce", 2], ["motes", 1]], "tally keeps pick-up order")
	equal(Relics.count(["pierce", "motes", "pierce"], "pierce"), 2, "count")
