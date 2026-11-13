extends "res://tests/test_suite.gd"
## Command-line switches.


func _parse(args: Array) -> LaunchOptions:
	return LaunchOptions.parse(PackedStringArray(args))


func test_plain_launch() -> void:
	var o := _parse([])
	check(not o.is_dev_session(), "no switches: a normal session")
	equal(o.start, LaunchOptions.START_TITLE, "starts at the title")
	equal(o.run_seed, -1, "random seed")
	check(not o.autoplay and not o.god and not o.run_tests, "nothing enabled")


func test_bot_run() -> void:
	var o := _parse(["--autoplay", "--god", "--seed=7", "--quit-after=900"])
	check(o.autoplay and o.god, "flags")
	equal(o.run_seed, 7, "seed")
	approx(o.quit_after, 900.0, "quit-after")
	equal(o.start, "run", "the bot skips the title")
	equal(o.start_depth(), 1, "and starts at depth 1")
	check(o.is_dev_session(), "a dev session")


func test_start_and_debug() -> void:
	var o := _parse(["--start=boss5", "--debug=boss,map", "--shots=C:/tmp/shots", "--shot-every=0.5"])
	equal(o.start_depth(), 5, "boss5 -> depth 5")
	check(o.has_debug("boss") and o.has_debug("map") and not o.has_debug("shop"), "debug flags")
	equal(o.shots_dir, "C:/tmp/shots", "screenshot folder")
	approx(o.shot_every, 0.5, "screenshot interval")
	equal(_parse(["--start=depth3"]).start_depth(), 3, "depth3")
	equal(_parse(["--start=depth99"]).start_depth(), Depths.FINAL, "depth clamped")
	equal(_parse(["--start=camp"]).start_depth(), 1, "camp has no depth of its own")
	equal(_parse(["--autoplay", "--start=camp"]).start, "camp", "an explicit start wins over the bot default")


func test_test_switches() -> void:
	var o := _parse(["--run-tests=shop"])
	check(o.run_tests, "run tests")
	equal(o.test_filter, "shop", "filter")
	equal(_parse(["--run-tests"]).test_filter, "", "no filter")
	check(_parse(["--update-golden"]).update_golden, "update golden")
	check(_parse(["--ai-smoke"]).ai_smoke and _parse(["--ai-smoke"]).is_dev_session(), "ai smoke")
	equal(_parse(["--ai-base=http://127.0.0.1:8080/v1"]).ai_base, "http://127.0.0.1:8080/v1", "value with = and : kept whole")


func test_unknown_switches_are_reported() -> void:
	var o := _parse(["--frobnicate", "--seed=3"])
	equal(Array(o.unknown), ["--frobnicate"], "unknown switch collected")
	equal(o.run_seed, 3, "the rest still parsed")
