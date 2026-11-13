extends "res://tests/test_suite.gd"
## The enemy catalogue and room wave composition.


func test_every_entry_has_a_script_and_art() -> void:
	for kind: String in Bestiary.ENTRIES:
		check(ResourceLoader.exists(Bestiary.script_path(kind)), kind + ": script exists")
		var enemy := Bestiary.create(kind)
		check(enemy != null, kind + ": can be created")
		if enemy == null:
			continue
		equal(enemy.kind, kind, kind + ": knows its kind")
		equal(enemy.is_boss(), Bestiary.boss_title(kind) != "", kind + ": boss flag matches the catalogue")
		check(Bestiary.display_name(kind) != "", kind + ": has a name")
		enemy._configure()
		check(SpriteLib.manifest().has(enemy.sheet), kind + ": sprite sheet " + enemy.sheet)
		check(enemy.max_hp > 0.0, kind + ": has health")
		enemy.free()


func test_pools_only_hold_spawnable_enemies() -> void:
	for depth: int in Bestiary.POOLS:
		for kind: String in Bestiary.POOLS[depth]:
			check(Bestiary.has(kind), "depth %d: %s is in the catalogue" % [depth, kind])
			check(Bestiary.cost(kind) > 0, "depth %d: %s has a cost" % [depth, kind])
	for depth in range(1, Depths.FINAL + 1):
		check(Bestiary.POOLS.has(depth), "pool for depth %d" % depth)
		if Depths.boss(depth) != "":
			check(Bestiary.boss_title(Depths.boss(depth)) != "", "depth %d boss is a boss" % depth)


func test_waves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for depth in range(1, Depths.FINAL + 1):
		for k in 100:
			var area := rng.randi_range(150, 375)
			var waves := Bestiary.compose(rng, depth, area)
			check(waves.size() >= 1 and waves.size() <= 2, "1-2 waves")
			var spent := 0
			for wave: Array in waves:
				check(wave.size() >= 1 and wave.size() <= Bestiary.MAX_WAVE_SIZE, "wave size sane")
				for kind: String in wave:
					check(Bestiary.POOLS[depth].has(kind), "depth %d wave uses its pool (%s)" % [depth, kind])
					spent += Bestiary.cost(kind)
			check(spent <= Bestiary.room_budget(depth, area), "waves stay within the room budget")


func test_difficulty_grows_with_depth() -> void:
	approx(Bestiary.hp_scale(1), 1.0, "depth 1 is the baseline")
	for depth in range(2, Depths.FINAL + 1):
		check(Bestiary.hp_scale(depth) > Bestiary.hp_scale(depth - 1), "hp grows at depth %d" % depth)
		check(Bestiary.room_budget(depth, 200) > Bestiary.room_budget(depth - 1, 200), "budget grows at depth %d" % depth)
	equal(Bestiary.display_name("nothing"), "未知", "unknown kind")
	equal(Bestiary.display_name("", "黑暗"), "黑暗", "custom fallback")
