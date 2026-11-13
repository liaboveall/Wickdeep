class_name TitleScreen
extends Control
## Title: animated logo over drifting embers, menu, run statistics and AI status.

const LOGO_TOP := 48.0
const MENU_WIDTH := 140
const AI_ON_COLOR := Color("#5797ad")

var game: Game
var _wick: AnimatedSprite2D
var _logo: TextureRect
var _ai_status: Label


func _ready() -> void:
	Ui.fill_parent(self)
	theme = UiTheme.theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_backdrop()
	_build_logo()
	_build_menu()
	_build_footer()
	Sound.music("camp")


func _build_backdrop() -> void:
	var backdrop := ColorRect.new()
	Ui.fill_parent(backdrop)
	backdrop.material = Fx.shader_material("title_backdrop")
	add_child(backdrop)
	var embers := CPUParticles2D.new()
	embers.position = Vector2(View.W / 2.0, View.H + 20)
	embers.amount = 60
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(330, 10)
	embers.direction = Vector2.UP
	embers.spread = 20.0
	embers.gravity = Vector2(0, -6)
	embers.initial_velocity_min = 15.0
	embers.initial_velocity_max = 45.0
	embers.color = UiTheme.AMBER
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 0.6, 0.4, 0.8), Color(1, 0.4, 0.3, 0)])
	embers.color_ramp = ramp
	add_child(embers)


func _build_logo() -> void:
	_logo = TextureRect.new()
	_logo.texture = SpriteLib.ui("logo")
	_logo.stretch_mode = TextureRect.STRETCH_SCALE
	var logo_size: Vector2 = _logo.texture.get_size() * 2.0
	_logo.size = logo_size
	_logo.position = Vector2((View.W - logo_size.x) / 2.0, LOGO_TOP)
	add_child(_logo)
	var name_cn := Ui.screen_line("灯 芯 深 渊", LOGO_TOP + logo_size.y + 6, UiTheme.CREAM, 24)
	name_cn.size.y = 28
	UiTheme.outlined(name_cn, 3, Color("#5e1a28"))
	add_child(name_cn)
	add_child(Ui.screen_line("提着最后一盏灯，走进吞噬光明的深渊。", LOGO_TOP + logo_size.y + 38, UiTheme.MIST))
	_wick = SpriteLib.make_sprite("wick", "idle")
	_wick.scale = Vector2(2, 2)
	_wick.position = Vector2(View.W / 2.0 + logo_size.x / 2.0 + 18, 70)
	add_child(_wick)


func _build_menu() -> void:
	var menu := Ui.vbox(5)
	menu.position = Vector2((View.W - MENU_WIDTH) / 2.0, 200)
	menu.size = Vector2(MENU_WIDTH, 100)
	add_child(menu)
	if SaveData.has_run():
		var next_depth := int(SaveData.load_run().get("depth", 1))
		menu.add_child(Ui.button("继续旅程（第%d层前）" % next_depth, game.continue_run, MENU_WIDTH))
	menu.add_child(Ui.button("新的旅程", game.start_run, MENU_WIDTH))
	menu.add_child(Ui.button("设置", game.pilot.settings, MENU_WIDTH))
	menu.add_child(Ui.button("退出", game.quit_game, MENU_WIDTH))
	(menu.get_child(0) as Button).grab_focus.call_deferred()


func _build_footer() -> void:
	add_child(Ui.screen_line("下深渊 %d 次 · 通关 %d 次 · 最深到达第 %d 层 · 累计击败 %d" % [
		SaveData.runs, SaveData.wins, maxi(1, SaveData.best_depth), SaveData.total_kills], 318, UiTheme.DIM))
	_ai_status = Ui.screen_line("", 334, UiTheme.DIM)
	add_child(_ai_status)
	Settings.changed.connect(_show_ai_status)
	_show_ai_status()
	var version := UiTheme.pixel_label("V" + str(ProjectSettings.get_setting("application/config/version")), UiTheme.DIM, false)
	version.position = Vector2(6, View.H - 10)
	add_child(version)


func _show_ai_status() -> void:
	if Settings.ai_available():
		_ai_status.text = "AI 角色：已启用（%s）" % Settings.model
		_ai_status.add_theme_color_override("font_color", AI_ON_COLOR)
	else:
		_ai_status.text = "AI 角色：未配置 API Key，使用预设台词（可在设置中填写 DeepSeek Key）"
		_ai_status.add_theme_color_override("font_color", UiTheme.DIM)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_wick.position.y = 70 + sin(t * 2.0) * 3.0
	_logo.modulate = Color(1, 1, 1) * (0.94 + 0.06 * sin(t * 3.1))
