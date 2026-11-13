class_name LaunchOptions
extends RefCounted
## Command-line switches (everything after `--` on the Godot command line). All of them exist for
## automated testing; a normal launch has none, and every field keeps its default.
##
##   --run-tests[=FILTER]   run the unit tests (optionally only suites whose name contains FILTER)
##   --update-golden        rewrite tests/golden/baseline.json from the current code
##   --ui-tour              press through every screen and menu, checking each step
##   --autoplay             let the bot play            --god        the player takes no damage
##   --seed=N               fixed dungeon seed          --quit-after=SECONDS
##   --start=camp|depthN|bossN|death|victory            jump straight to a screen
##   --debug=FLAG,FLAG      boss, showcase, map, shop, haggle, wick, ask, relic, pause, settings
##   --shots=DIR --shot-every=SECONDS                   save screenshots (needs a window)
##   --ai-smoke             one request with an invalid key, to check error handling
##   --ai-base=URL          point the AI client at a local mock      --with-ai  keep AI on for the bot

const START_TITLE := "title"

var run_tests := false
var test_filter := ""
var update_golden := false
var ui_tour := false
var autoplay := false
var god := false
var run_seed := -1              # -1 = random
var start := START_TITLE
var debug := PackedStringArray()
var shots_dir := ""
var shot_every := 0.0
var quit_after := 0.0
var ai_smoke := false
var ai_base := ""
var with_ai := false
var unknown := PackedStringArray()


static func parse(args: PackedStringArray) -> LaunchOptions:
	var o := LaunchOptions.new()
	for arg in args:
		var key := arg.get_slice("=", 0)
		var value := arg.substr(key.length() + 1)
		match key:
			"--run-tests":
				o.run_tests = true
				o.test_filter = value
			"--update-golden":
				o.update_golden = true
			"--ui-tour":
				o.ui_tour = true
			"--autoplay":
				o.autoplay = true
			"--god":
				o.god = true
			"--seed":
				o.run_seed = int(value)
			"--start":
				o.start = value
			"--debug":
				o.debug = value.split(",", false)
			"--shots":
				o.shots_dir = value
			"--shot-every":
				o.shot_every = float(value)
			"--quit-after":
				o.quit_after = float(value)
			"--ai-smoke":
				o.ai_smoke = true
			"--ai-base":
				o.ai_base = value
			"--with-ai":
				o.with_ai = true
			_:
				o.unknown.append(arg)
	# the bot has no use for the title screen: go straight into a run
	if o.autoplay and o.start == START_TITLE:
		o.start = "run"
	return o


func has_debug(flag: String) -> bool:
	return flag in debug


## True when any testing switch is set. Such sessions save into a sandbox, never the real profile.
func is_dev_session() -> bool:
	return run_tests or update_golden or ui_tour or autoplay or god or run_seed >= 0 or start != START_TITLE \
		or not debug.is_empty() or shots_dir != "" or quit_after > 0.0 or ai_smoke or ai_base != ""


## Depth named by --start=depth3 / --start=boss5, or 1.
func start_depth() -> int:
	for prefix: String in ["depth", "boss"]:
		if start.begins_with(prefix):
			return clampi(int(start.trim_prefix(prefix)), 1, Depths.FINAL)
	return 1
