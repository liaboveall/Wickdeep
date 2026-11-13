class_name Game
extends Node
## Root of the game. Owns the screen that is showing (title, a dungeon level, the camp, the end
## screen), fades between them, and moves a run along: start -> level -> camp -> level -> ... -> end.
##
## Screens get a reference to this node as `game` and call the methods under "run flow".
## Menus go through `pilot`, test switches live in `options` and src/dev/dev_tools.gd.

signal screen_ready(screen: Node)       # a new screen was added, before it fades in
signal run_finished(victory: bool)

const FADE_OUT := 0.3
const FADE_IN := 0.35
const FADE_LAYER := 100

var options: LaunchOptions
var pilot: Pilot
var overlays: OverlayStack
var dev: DevTools
var screen: Node
## Losing window focus opens the pause menu. Test sessions switch this off: their window sits in
## the background, and a pause menu would cover whatever they are checking.
var pause_on_focus_loss := true
var _fade: ColorRect
var _fade_tween: Tween
var _switching := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	options = LaunchOptions.parse(OS.get_cmdline_user_args())
	for arg in options.unknown:
		printerr("Unknown switch ignored: ", arg)
	overlays = OverlayStack.new()
	overlays.game = self
	add_child(overlays)
	_build_fade()
	get_window().focus_exited.connect(_on_focus_lost)
	get_window().min_size = View.SIZE_I
	if options.is_dev_session():
		SaveData.use_sandbox()
		dev = DevTools.new(self)
		add_child(dev)
	pilot = BotPilot.new(self) if options.autoplay else Pilot.new(self)
	var started := false
	if dev:
		started = await dev.take_over_startup()
	if not started:
		show_title()


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = FADE_LAYER
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = View.BACKDROP
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


# ------------------------------------------------------------------ run flow
func show_title() -> void:
	Run.active = false
	_switch(func() -> Node:
		var title := TitleScreen.new()
		title.game = self
		return title)


func start_run() -> void:
	Run.new_run(options.run_seed)
	enter_level()


func continue_run() -> void:
	var checkpoint := SaveData.load_run()
	if checkpoint.is_empty():
		start_run()
		return
	Run.from_dict(checkpoint)
	enter_camp()


## The stairs at the end of a level: bank the depth and rest at the camp.
func descend() -> void:
	Run.finish_depth()
	enter_camp()


## The stairs out of the camp.
func next_depth() -> void:
	enter_level()


func enter_level() -> void:
	_switch(func() -> Node:
		var level := Level.new()
		level.game = self
		return level)


func enter_camp() -> void:
	_switch(func() -> Node:
		var camp := Camp.new()
		camp.game = self
		return camp)


## The run is over, one way or the other: show Wick's epitaph and the statistics.
func finish_run(victory: bool) -> void:
	if not Run.active:
		return   # already over (two endings can race: the last boss falls as the player does)
	Run.end_run(victory)
	run_finished.emit(victory)
	_switch(func() -> Node:
		var end := EndScreen.new()
		end.game = self
		end.victory = victory
		return end)


func abandon_run() -> void:
	Run.end_run(false)
	show_title()


func quit_game() -> void:
	SaveData.save_data()
	get_tree().quit()


# ------------------------------------------------------------------ screens
func _switch(make_screen: Callable) -> void:
	if _switching:
		return
	_switching = true
	await _fade_to(1.0, FADE_OUT)
	overlays.clear()
	Juice.reset()
	if is_instance_valid(screen):
		screen.queue_free()
		await get_tree().process_frame
	screen = make_screen.call()
	add_child(screen)
	move_child(screen, 0)
	_switching = false
	screen_ready.emit(screen)
	_fade_to(0.0, FADE_IN)


## Fade the black cover in or out. A new fade replaces one still running, so a quick click
## during a fade-in cannot leave the two fighting over the screen.
func _fade_to(alpha: float, seconds: float) -> Signal:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", alpha, seconds)
	return _fade_tween.finished


## False while one screen is being swapped for another.
func can_interact() -> bool:
	return not _switching and is_instance_valid(screen)


# ------------------------------------------------------------------ pausing
func can_pause() -> bool:
	var world := screen as World
	return world != null and overlays.is_empty() and can_interact() \
		and world.player != null and not world.player.dead


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F11:
		Settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and can_pause():
		get_viewport().set_input_as_handled()
		Sound.play("ui_select")
		pilot.pause()


func _on_focus_lost() -> void:
	if pause_on_focus_loss and pilot.pauses_on_focus_loss() and can_pause():
		pilot.pause()
