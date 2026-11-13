extends "res://tests/test_suite.gd"
## Run state: health, relics, statistics, depth bookkeeping and the checkpoint.


func before_each() -> void:
	fresh_run(42)


func test_new_run() -> void:
	check(Run.active, "active")
	equal(Run.seed_value, 42, "forced seed")
	equal(Run.depth, 1, "starts at depth 1")
	equal(Run.hp, Run.BASE_MAX_HP, "full health")
	equal(Run.relics.size(), 0, "no relics")
	equal(SaveData.runs, 1, "counted in the profile")
	Run.new_run()
	check(Run.seed_value >= 0 and Run.seed_value < 1000000, "random seed in range")


func test_damage_and_death() -> void:
	check(not Run.take_damage(2, "slime"), "survives a hit")
	equal(Run.hp, 4, "hp reduced")
	equal(Run.damage_taken, 2, "damage counted")
	check(Run.take_damage(10, "archer"), "dies from a big hit")
	equal(Run.hp, 0, "hp never negative")
	equal(Run.killer, "archer", "killer recorded")
	equal(Run.hurt_by, {"slime": 2, "archer": 10}, "damage by source")
	equal(Run.depth_log.worst_enemy(), "archer", "worst enemy of the depth")


func test_revive() -> void:
	Run.add_relic("second_wick")
	check(not Run.take_damage(99, "knight"), "second wick saves the player once")
	equal(Run.hp, Run.REVIVE_HP, "revived with some health")
	check(Run.revive_used, "revive spent")
	check(Run.take_damage(99, "knight"), "but only once")


func test_relics_and_max_hp() -> void:
	Run.take_damage(3, "bat")
	Run.add_relic("thick_wax")
	equal(Run.max_hp, 8, "thick wax raises the cap")
	equal(Run.hp, 5, "and fills the new wax")
	Run.add_relic("greedy_lamp")
	equal(Run.max_hp, 6, "greedy lamp lowers it")
	equal(Run.hp, 5, "health unchanged while it still fits")
	Run.hp = 6
	Run.relics.erase("thick_wax")
	Run.recompute_stats()
	equal(Run.max_hp, 4, "cap follows the relics")
	equal(Run.hp, 4, "health clamped to the cap")
	check("thick_wax" in SaveData.seen_relics, "relic recorded as seen")


func test_embers_and_flare() -> void:
	check(not Run.spend(1), "cannot spend what you do not have")
	Run.add_embers(10)
	check(Run.spend(4) and Run.embers == 6, "spending")
	Run.register_damage_dealt(100.0)
	approx(Run.flare, 25.0, "a quarter of damage dealt charges the flare")
	Run.add_relic("calm_flame")
	Run.register_damage_dealt(100.0)
	approx(Run.flare, 62.5, "calm flame charges 50% faster")
	Run.add_flare(1000.0)
	check(Run.flare_ready() and is_equal_approx(Run.flare, Run.FLARE_MAX), "capped when ready")
	Run.spend_flare()
	check(not Run.flare_ready(), "spent")


func test_moth_heart() -> void:
	Run.add_relic("moth_heart")
	Run.take_damage(2, "slime")
	for k in Run.MOTH_KILLS_PER_HEAL - 1:
		Run.register_kill("bat")
	equal(Run.hp, 4, "not yet")
	Run.register_kill("bat")
	equal(Run.hp, 5, "heals one point every 25 kills")
	equal(Run.kills, Run.MOTH_KILLS_PER_HEAL, "kills counted")
	check("bat" in SaveData.seen_enemies, "enemy recorded as seen")


func test_finishing_a_depth() -> void:
	Run.take_damage(1, "pod")
	Run.register_kill("pod")
	Run.register_kill("slime")
	Run.camp.haggles_used = 3
	Run.camp.rested = true
	Run.finish_depth()
	equal(Run.depth, 2, "next depth")
	var last := Run.last_depth()
	equal(last.depth, 1, "summary is for the depth just finished")
	equal(last.kills, 2, "kills in summary")
	equal(last.damage_taken, 1, "damage in summary")
	equal(last.worst_enemy, "pod", "worst enemy in summary")
	equal(Run.depth_log.total_kills(), 0, "the log starts over")
	check(Run.camp.haggles_used == 0 and not Run.camp.rested, "a new camp visit")
	equal(SaveData.best_depth, 2, "best depth recorded")


func test_checkpoint_round_trip() -> void:
	Run.add_relic("twin_wick")
	Run.add_relic("thick_wax")
	Run.add_embers(77)
	Run.take_damage(3, "bat")
	Run.finish_depth()
	Run.camp.stock = ["pierce", "oil"]
	Run.camp.sold = ["oil"]
	Run.camp.price_mult = 0.84
	Run.camp.haggles_used = 2
	Run.camp.story_told = true
	Run.camp.rested = true
	Run.save_checkpoint()
	check(SaveData.has_run(), "checkpoint written")
	var saved := SaveData.load_run()
	Run.new_run(1)
	Run.from_dict(saved)
	equal(Run.seed_value, 42, "seed")
	equal(Run.depth, 2, "depth")
	equal(Run.relics, ["twin_wick", "thick_wax"], "relics")
	equal(Run.stats.projectiles, 2, "stats recomputed from the relics")
	equal(Run.max_hp, 8, "max hp recomputed")
	equal(Run.hp, 5, "hp")
	equal(Run.embers, 77, "embers")
	equal(Run.camp.stock, ["pierce", "oil"], "stock")
	equal(Run.camp.sold, ["oil"], "sold")
	approx(Run.camp.price_mult, 0.84, "haggled price")
	equal(Run.camp.haggles_used, 2, "haggles used")
	check(Run.camp.story_told and Run.camp.rested, "visit flags")
	equal(int(Run.last_depth().depth), 1, "history")
	Run.end_run(false)
	check(not SaveData.has_run(), "ending the run clears the checkpoint")
	check(not Run.active, "run over")


func test_checkpoint_tolerates_junk() -> void:
	Run.from_dict({"depth": 99, "hp": -5, "relics": ["twin_wick", "no_such_relic", 7], "history": "oops",
		"shop_stock": "nope"})
	equal(Run.depth, Depths.FINAL, "depth clamped")
	equal(Run.relics, ["twin_wick"], "unknown relics dropped")
	equal(Run.hp, 1, "hp at least 1")
	equal(Run.history, [], "bad history ignored")
	equal(Run.camp.stock, [], "bad stock ignored")
	Run.from_dict({})
	equal(Run.depth, 1, "empty checkpoint gives a fresh state")
	equal(Run.hp, Run.max_hp, "at full health")


func test_victory_counts() -> void:
	Run.end_run(true)
	check(Run.won, "won")
	equal(SaveData.wins, 1, "win recorded")
