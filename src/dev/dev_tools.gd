class_name DevTools
extends Node
## Everything that only exists for automated testing, kept out of the game proper: unit tests,
## jumping straight to a screen, opening a menu for a screenshot, timed screenshots, the bot's
## progress log. Game creates this node only when a test switch is on the command line
## (see LaunchOptions); those sessions also save into a sandbox instead of the real profile.

const TEST_RUNNER := "res://tests/test_runner.gd"
const SHOWCASE_KINDS := ["slime", "bat", "archer", "pod", "wisp", "knight", "shade"]
const PROGRESS_INTERVAL := 5            # seconds between the bot's progress lines
const MENU_DELAY := 0.8                 # after the fade-in, before a debug menu opens

var game: Game
var options: LaunchOptions
var _started_ms := 0
var _next_shot := 0.0
var _shot_count := 0
var _progress_ticks := 0


func _init(game_root: Game) -> void:
	game = game_root
	options = game_root.options
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	Settings.persist = false   # test sessions tweak settings in memory; never write them back
	game.pause_on_focus_loss = false
	game.screen_ready.connect(_on_screen_ready)
	game.run_finished.connect(_on_run_finished)


func elapsed() -> float:
	return (Time.get_ticks_msec() - _started_ms) / 1000.0


# ------------------------------------------------------------------ startup
## Returns true if a test mode started something other than the title screen.
func take_over_startup() -> bool:
	if options.ai_base != "":
		# point the AI client at a local mock server
		Settings.set_ai(true, "mock-key", options.ai_base, Settings.model)
	if options.autoplay and not options.with_ai:
		Settings.ai_enabled = false
	if options.ai_smoke:
		await _ai_smoke()
		return true
	if options.run_tests or options.update_golden:
		_run_tests()
		return true
	if options.ui_tour:
		var tour := UiTour.new(game)
		add_child(tour)
		tour.run()
		return false   # the tour starts from the title screen, like a player would
	match options.start:
		LaunchOptions.START_TITLE:
			return false
		"death", "victory":
			_fake_run_in_progress()
			game.finish_run(options.start == "victory")
		"camp":
			Run.new_run(options.run_seed)
			Run.finish_depth()
			game.enter_camp()
		_:
			Run.new_run(options.run_seed)
			Run.depth = options.start_depth()
			game.enter_level()
	return true


func _run_tests() -> void:
	if not ResourceLoader.exists(TEST_RUNNER):
		printerr("The unit tests are not part of exported builds.")
		get_tree().quit(2)
		return
	var failures: int = load(TEST_RUNNER).new().run(options.test_filter, options.update_golden)
	get_tree().quit(1 if failures > 0 else 0)


## Network smoke test with a deliberately invalid key: the request must fail cleanly.
func _ai_smoke() -> void:
	Settings.set_ai(true, "sk-invalid-smoke-test", Settings.base_url, Settings.model)
	get_tree().paused = true   # menus pause the game; the request must still complete
	var res: Dictionary = await AI.test_connection()
	get_tree().paused = false
	print("AI_SMOKE ok=%s error=%s latency=%.2f endpoint=%s model=%s" % [res.ok, res.error,
		res.get("latency", 0.0), AI.endpoint(), Settings.model])
	get_tree().quit()


## A plausible run to end, so the death and victory screens have something to show.
func _fake_run_in_progress() -> void:
	Run.new_run(options.run_seed)
	Run.depth = 3
	Run.kills = 57
	Run.time = 734.0
	Run.killer = "archer"
	Run.add_relic("twin_wick")
	Run.add_relic("keen_spark")


# ------------------------------------------------------------------ per screen
func _on_screen_ready(screen: Node) -> void:
	var world := screen as World
	if world:
		world.hud.force_big_map = options.has_debug("map")
	if screen is Level:
		_prepare_level(screen)
	if not options.debug.is_empty():
		_open_debug_menu(screen)


func _prepare_level(level: Level) -> void:
	if options.has_debug("boss"):
		# stand just inside the room the depth ends in
		var room := level.gen.goal_room()
		level.player.global_position = NavGrid.cell_center(Vector2i(room.center.x, room.rect.end.y - 3))
		level.camera.snap_to_target()
	if options.has_debug("showcase"):
		# one of every ordinary enemy in a ring around the player
		for i in SHOWCASE_KINDS.size():
			var angle := i * TAU / SHOWCASE_KINDS.size()
			var pos := level.player.global_position + Vector2(cos(angle) * 80.0, sin(angle) * 52.0)
			if not level.grid.is_solid_at(pos):
				level.spawn_enemy(SHOWCASE_KINDS[i], pos, level.depth)
		level.director.hold(0)


## Open a menu right away so automated screenshots can capture it.
func _open_debug_menu(screen: Node) -> void:
	await _wait(Game.FADE_IN + MENU_DELAY)
	if not is_instance_valid(screen) or screen != game.screen:
		return
	if options.has_debug("shop") and screen is Camp:
		var shop := game.overlays.push(ShopUi.new()) as ShopUi
		if options.has_debug("haggle"):
			await _wait(0.5)
			shop.say_to_granny("您这些货真是精品，便宜点吧！")
	elif options.has_debug("wick") and screen is Camp:
		var dialog := game.overlays.push(WickDialog.new()) as WickDialog
		if options.has_debug("ask"):
			await _wait(0.5)
			dialog.ask("你好呀，灯芯")
	elif options.has_debug("relic") and screen is Level:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var menu := RelicChoice.new()
		menu.ids = Relics.roll(rng, [], 3)
		game.overlays.push(menu)
	elif options.has_debug("pause") and screen is World:
		for id: String in ["twin_wick", "searing", "glass_shade"]:
			Run.add_relic(id)
		game.overlays.push(PauseMenu.new())
	elif options.has_debug("settings"):
		game.overlays.push(SettingsMenu.new())


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# ------------------------------------------------------------------ while running
func _process(_delta: float) -> void:
	var now := elapsed()
	if options.shots_dir != "" and options.shot_every > 0.0 and now >= _next_shot:
		_next_shot = now + options.shot_every
		screenshot()
	if options.autoplay and int(now) / PROGRESS_INTERVAL != _progress_ticks:
		_progress_ticks = int(now) / PROGRESS_INTERVAL
		_print_progress(now)
	if options.quit_after > 0.0 and now >= options.quit_after:
		_print_summary("timeout")
		get_tree().quit()


func screenshot(tag := "") -> void:
	if options.shots_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(options.shots_dir)
	var image := get_viewport().get_texture().get_image()
	if image == null:
		return
	_shot_count += 1
	image.save_png("%s/shot_%03d%s.png" % [options.shots_dir, _shot_count, ("_" + tag) if tag != "" else ""])


func _on_run_finished(victory: bool) -> void:
	_print_summary("victory" if victory else "death")
	if options.autoplay and options.quit_after > 0.0:
		get_tree().quit()


func _print_progress(now: float) -> void:
	var where := "title"
	var level := game.screen as Level
	if level:
		where = "depth %d room %d active %d enemies %d" % [Run.depth, level.director.current,
			level.director.active, level.enemies.size()]
	elif game.screen is Camp:
		where = "camp before depth %d" % Run.depth
	print("[%5.1fs] %s hp %d/%d kills %d relics %d ts %.2f paused %s" % [now, where, Run.hp, Run.max_hp,
		Run.kills, Run.relics.size(), Engine.time_scale, get_tree().paused])


func _print_summary(reason: String) -> void:
	print("RUN_SUMMARY reason=%s depth=%d hp=%d/%d kills=%d time=%d relics=%s embers=%d killer=%s hurt_by=%s" % [
		reason, Run.depth, Run.hp, Run.max_hp, Run.kills, int(Run.time), ",".join(Run.relics), Run.embers,
		Run.killer, JSON.stringify(Run.hurt_by)])
