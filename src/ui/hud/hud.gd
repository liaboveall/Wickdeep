class_name Hud
extends CanvasLayer
## In-game HUD for levels and the camp: health, embers, flare charge, relics, minimap, interaction
## prompt, toasts, banners, the boss bar, the crosshair and the low-health vignette.

const LAYER := 10
const MARGIN := 6
const LOW_HP := 2                 # at or below this the screen edge pulses red
const HURT_FLASH := 0.65
const TOAST_HOLD := 1.8
const CONTROLS_HINT := "WASD 移动  ·  鼠标瞄准，左键射击  ·  空格/右键 冲刺  ·  Q 爆燃  ·  E 交互  ·  Tab 地图"
const BOSS_BAR_WIDTH := 300

var world: World
var player: Player
var force_big_map := false        # test switch: keep the full map on screen
var root: Control

var _hearts: HBoxContainer
var _embers: Label
var _flare_ready: TextureRect
var _relics: HFlowContainer
var _relic_count := -1
var _minimap: Minimap
var _big_map: Minimap
var _minimap_dirty := true
var _depth_label: Label
var _prompt: HBoxContainer
var _prompt_label: Label
var _prompt_target: Node2D
var _toast: Label
var _toast_tween: Tween
var _banner: VBoxContainer
var _boss_box: VBoxContainer
var _boss_bar: ProgressBar
var _boss_name: Label
var _boss: Enemy
var _vignette: ShaderMaterial
var _crosshair: Sprite2D


func _ready() -> void:
	layer = LAYER
	root = Control.new()
	Ui.fill_parent(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.theme()
	add_child(root)
	_build_vignette()
	_build_vitals()
	_build_relic_tray()
	_build_maps()
	_build_prompt()
	_build_toast()
	_build_boss_bar()
	_crosshair = Sprite2D.new()
	_crosshair.texture = SpriteLib.ui("crosshair")
	add_child(_crosshair)
	Run.changed.connect(_refresh)
	_refresh()


# ------------------------------------------------------------------ construction
func _build_vignette() -> void:
	var rect := ColorRect.new()
	Ui.fill_parent(rect)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = Fx.shader_material("vignette")
	_vignette.set_shader_parameter("strength", 0.0)
	rect.material = _vignette
	root.add_child(rect)


## Top left: health flames, embers, flare charge.
func _build_vitals() -> void:
	var column := Ui.vbox(3)
	column.position = Vector2(MARGIN, 5)
	root.add_child(column)
	_hearts = Ui.hbox(1)
	column.add_child(_hearts)
	var purse := Ui.hbox(3)
	purse.add_child(Ui.image(SpriteLib.ui("ember_icon")))
	_embers = UiTheme.pixel_label("0", UiTheme.GOLD, true)
	purse.add_child(_embers)
	column.add_child(purse)
	var flare := Ui.hbox(3)
	var bar := FlareBar.new()
	bar.custom_minimum_size = Vector2(36, 5)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flare.add_child(bar)
	_flare_ready = TextureRect.new()
	_flare_ready.texture = SpriteLib.ui("key_q")
	_flare_ready.visible = false
	flare.add_child(_flare_ready)
	column.add_child(flare)


## Bottom left: one icon per kind of relic owned.
func _build_relic_tray() -> void:
	_relics = HFlowContainer.new()
	_relics.position = Vector2(MARGIN, View.H - 22)
	_relics.size = Vector2(420, 18)
	_relics.add_theme_constant_override("h_separation", 2)
	_relics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_relics)


## Top right: the minimap and the depth name; plus the full-screen map, hidden until asked for.
func _build_maps() -> void:
	_minimap = Minimap.new()
	_minimap.hud = self
	_minimap.position = Vector2(View.W - 52, MARGIN)
	_minimap.size = Vector2(46, 34)
	root.add_child(_minimap)
	_depth_label = UiTheme.label("", UiTheme.MIST)
	_depth_label.position = Vector2(View.W - 160, 42)
	_depth_label.size = Vector2(154, 14)
	_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_depth_label)
	_big_map = Minimap.new()
	_big_map.hud = self
	_big_map.scale_px = 1.8
	_big_map.big = true
	Ui.fill_parent(_big_map)
	_big_map.visible = false
	root.add_child(_big_map)


## "[E] do the thing", floating above whatever is in reach.
func _build_prompt() -> void:
	_prompt = Ui.hbox(4)
	_prompt.visible = false
	_prompt.add_child(Ui.image(SpriteLib.ui("key_e")))
	_prompt_label = UiTheme.outlined(UiTheme.label(""))
	_prompt.add_child(_prompt_label)
	root.add_child(_prompt)


func _build_toast() -> void:
	_toast = UiTheme.outlined(Ui.screen_line("", 62, UiTheme.GOLD))
	_toast.size.y = 16
	_toast.modulate.a = 0.0
	root.add_child(_toast)


func _build_boss_bar() -> void:
	_boss_box = Ui.vbox(2)
	_boss_box.position = Vector2((View.W - BOSS_BAR_WIDTH) / 2.0, 14)
	_boss_box.size = Vector2(BOSS_BAR_WIDTH, 30)
	_boss_box.visible = false
	root.add_child(_boss_box)
	_boss_name = UiTheme.outlined(Ui.centered_label(""))
	_boss_box.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(BOSS_BAR_WIDTH, 6)
	_boss_bar.add_theme_stylebox_override("background", _bar_style(UiTheme.INK))
	_boss_bar.add_theme_stylebox_override("fill", _bar_style(UiTheme.RED))
	_boss_box.add_child(_boss_bar)


func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = View.BACKDROP
	style.set_border_width_all(1)
	return style


# ------------------------------------------------------------------ every frame
func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_update_vignette(delta)
	_update_crosshair()
	_flare_ready.visible = Run.flare_ready()
	if _flare_ready.visible:
		_flare_ready.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)
	if is_instance_valid(_boss):
		_boss_bar.value = _boss.hp / _boss.max_hp * 100.0
	if _prompt.visible and is_instance_valid(_prompt_target):
		var above: Vector2 = get_viewport().get_canvas_transform() * (_prompt_target.global_position + Vector2(0, -30))
		_prompt.position = (above - Vector2(_prompt.size.x / 2.0, 0)).round()
	_update_maps()


## Fades after a hit; keeps pulsing while health is critical.
func _update_vignette(delta: float) -> void:
	var floor_strength := 0.0
	if Run.hp <= LOW_HP and Run.max_hp > LOW_HP and not player.dead:
		floor_strength = 0.18 + 0.1 * sin(Time.get_ticks_msec() / 180.0)
	var current: float = _vignette.get_shader_parameter("strength")
	_vignette.set_shader_parameter("strength", maxf(floor_strength, current - delta * 1.5))


## The crosshair replaces the mouse cursor wherever the player can shoot.
func _update_crosshair() -> void:
	var aiming := world.combat_enabled and not player.dead and not get_tree().paused
	_crosshair.visible = aiming
	if aiming:
		if Inputs.using_gamepad:
			_crosshair.position = (get_viewport().get_canvas_transform() * player.input.aim_point).round()
		else:
			_crosshair.position = get_viewport().get_mouse_position().round()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if aiming else Input.MOUSE_MODE_VISIBLE


func _update_maps() -> void:
	_big_map.visible = (Input.is_action_pressed("map") or force_big_map) and not get_tree().paused
	# redraw when something changed, and a few times a second for the player's dot
	if _minimap_dirty or Engine.get_process_frames() % 10 == 0:
		_minimap_dirty = false
		_minimap.queue_redraw()
		if _big_map.visible:
			_big_map.queue_redraw()


# ------------------------------------------------------------------ run state
func _refresh() -> void:
	_refresh_hearts()
	_embers.text = str(Run.embers)
	if Run.relics.size() != _relic_count:
		_relic_count = Run.relics.size()
		_refresh_relics()
	_depth_label.text = Run.depth_title() if Run.active else ""


## One flame per two hit points, shown full, half or empty.
func _refresh_hearts() -> void:
	var wanted := int(ceil(Run.max_hp / 2.0))
	while _hearts.get_child_count() < wanted:
		_hearts.add_child(TextureRect.new())
	while _hearts.get_child_count() > wanted:
		var extra := _hearts.get_child(_hearts.get_child_count() - 1)
		_hearts.remove_child(extra)
		extra.queue_free()
	for i in wanted:
		var points := Run.hp - i * 2
		var fill := "full" if points >= 2 else ("half" if points == 1 else "empty")
		(_hearts.get_child(i) as TextureRect).texture = SpriteLib.region("hud_flame", fill)


func _refresh_relics() -> void:
	for icon in _relics.get_children():
		icon.queue_free()
	for entry: Array in Relics.tally(Run.relics):
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(16, 16)
		slot.tooltip_text = Relics.display_name(entry[0])
		var icon := TextureRect.new()
		icon.texture = SpriteLib.icon(entry[0])
		slot.add_child(icon)
		if entry[1] > 1:
			var copies := UiTheme.pixel_label(str(entry[1]), UiTheme.CREAM, true)
			copies.position = Vector2(10, 8)
			slot.add_child(copies)
		_relics.add_child(slot)


# ------------------------------------------------------------------ called by the world
func queue_minimap() -> void:
	_minimap_dirty = true


## Show the prompt of the interactable in reach (null hides it).
func set_prompt(target: Interactable) -> void:
	_prompt_target = target
	_prompt.visible = target != null
	if target:
		_prompt_label.text = target.prompt


func flash_damage() -> void:
	_vignette.set_shader_parameter("strength", HURT_FLASH)


## A short message in the upper middle of the screen.
func toast(message: String, color := UiTheme.GOLD) -> void:
	_toast.text = message
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_HOLD)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


## Big title that fades in and out when a place is entered.
func show_banner(title: String, subtitle := "") -> void:
	if _banner:
		_banner.queue_free()
	_banner = Ui.vbox(4)
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.position = Vector2(0, 120)
	_banner.size = Vector2(View.W, 60)
	_banner.add_child(UiTheme.big_label(title, UiTheme.GOLD, View.W))
	if subtitle != "":
		_banner.add_child(Ui.centered_label(subtitle, UiTheme.MIST))
	root.add_child(_banner)
	_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.8)


func show_controls_hint() -> void:
	var hint := UiTheme.outlined(Ui.screen_line(CONTROLS_HINT, 318, UiTheme.MIST))
	root.add_child(hint)
	var tw := create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(hint, "modulate:a", 0.0, 1.5)
	tw.tween_callback(hint.queue_free)


func show_boss(boss: Boss) -> void:
	_boss = boss
	_boss_name.text = boss.title()
	_boss_box.visible = true
	_boss_box.modulate.a = 0.0
	create_tween().tween_property(_boss_box, "modulate:a", 1.0, 0.8)


func hide_boss() -> void:
	_boss = null
	create_tween().tween_property(_boss_box, "modulate:a", 0.0, 0.5)
