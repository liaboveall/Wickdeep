class_name SettingsMenu
extends Overlay
## Settings: audio, display, feedback, and the DeepSeek AI connection (key typed by the player).
## Sliders and check boxes apply at once; everything is written to disk when the menu closes.

const CONTROLS_HELP := "操作：WASD 移动 · 鼠标瞄准\n左键射击 · 空格/右键冲刺\nQ 爆燃 · E 交互 · Tab 地图\n手柄：左摇杆移动 · 右摇杆瞄准\nRT 射击 · A 冲刺 · RB 爆燃 · X 交互"
const AI_NOTE := "对话会发送到上面的接口。Key 只保存在本机。\n没有 Key 时角色使用预设台词，游戏完整可玩。"
const AI_COLUMN_WIDTH := 270

var _key: LineEdit
var _url: LineEdit
var _model: LineEdit
var _ai_toggle: CheckBox
var _test_label: Label
var _test_button: Button


func _build() -> void:
	var window := panel(Vector2(600, 0))
	var rows := Ui.vbox(6)
	window.add_child(rows)
	rows.add_child(Ui.heading("设置"))
	var columns := Ui.hbox(14)
	rows.add_child(columns)
	columns.add_child(_build_general())
	columns.add_child(VSeparator.new())
	columns.add_child(_build_ai())
	var done := Ui.button("保存并返回", close)
	rows.add_child(Ui.center(done))
	add_centered(window)
	done.grab_focus.call_deferred()


# ------------------------------------------------------------------ sound and picture
func _build_general() -> Control:
	var column := Ui.vbox(5)
	column.add_child(UiTheme.label("声音与画面", UiTheme.GOLD))
	var options := Ui.grid(2, 8, 6)
	column.add_child(options)
	_slider(options, "主音量", "master_volume")
	_slider(options, "音乐", "music_volume")
	_slider(options, "音效", "sfx_volume")
	_slider(options, "屏幕震动", "screen_shake")
	_check(options, "全屏", "fullscreen")
	_check(options, "伤害数字", "damage_numbers")
	column.add_child(UiTheme.label(CONTROLS_HELP, UiTheme.DIM))
	return column


## A 0..1 slider bound to a property of Settings.
func _slider(parent: Control, text: String, property: String) -> void:
	parent.add_child(UiTheme.label(text))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.get(property)
	slider.custom_minimum_size = Vector2(170, 14)
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set(property, value)
		Settings.apply()
		Sound.play("ui_move", -6.0))
	parent.add_child(slider)


## A check box bound to a property of Settings.
func _check(parent: Control, text: String, property: String) -> void:
	parent.add_child(UiTheme.label(text))
	var box := CheckBox.new()
	box.button_pressed = Settings.get(property)
	box.toggled.connect(func(on: bool) -> void:
		Settings.set(property, on)
		Settings.apply()
		Sound.play("ui_select"))
	parent.add_child(box)


# ------------------------------------------------------------------ AI connection
func _build_ai() -> Control:
	var column := Ui.vbox(5)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UiTheme.label("AI 角色（DeepSeek）", UiTheme.GOLD))
	_ai_toggle = CheckBox.new()
	_ai_toggle.text = "启用 AI 对话（灯芯和秤婆由大模型扮演）"
	_ai_toggle.button_pressed = Settings.ai_enabled
	column.add_child(_ai_toggle)
	column.add_child(UiTheme.label("API Key"))
	_key = LineEdit.new()
	_key.secret = true
	_key.text = Settings.api_key
	_key.placeholder_text = "已从环境变量 %s 读取" % Settings.API_KEY_ENV if Settings.has_env_api_key() \
		else "从 platform.deepseek.com 创建后粘贴"
	_key.custom_minimum_size = Vector2(AI_COLUMN_WIDTH, 0)
	column.add_child(_key)
	var endpoint := Ui.grid(2, 6, 4)
	column.add_child(endpoint)
	endpoint.add_child(UiTheme.label("接口"))
	_url = LineEdit.new()
	_url.text = Settings.base_url
	_url.custom_minimum_size = Vector2(230, 0)
	endpoint.add_child(_url)
	endpoint.add_child(UiTheme.label("模型"))
	_model = LineEdit.new()
	_model.text = Settings.model
	endpoint.add_child(_model)
	var test_row := Ui.hbox(6)
	_test_button = Ui.button("测试连接", _test, 70)
	test_row.add_child(_test_button)
	column.add_child(test_row)
	_test_label = Ui.wrapped_label("", UiTheme.MIST, AI_COLUMN_WIDTH)
	column.add_child(_test_label)
	column.add_child(Ui.wrapped_label(AI_NOTE, UiTheme.DIM, AI_COLUMN_WIDTH))
	return column


## Copy the AI fields into Settings (in memory; close() writes the file).
func _store_ai() -> void:
	Settings.set_ai(_ai_toggle.button_pressed, _key.text, _url.text, _model.text)


func _show_test_result(text: String, color: Color) -> void:
	_test_label.text = text
	_test_label.add_theme_color_override("font_color", color)


func _test() -> void:
	_store_ai()
	if Settings.effective_api_key() == "":
		_show_test_result("还没有填写 API Key。", UiTheme.RED)
		return
	_test_button.disabled = true
	_show_test_result("正在连接……", UiTheme.MIST)
	# the test should work even while "enable AI" is unticked
	Settings.ai_enabled = true
	AI.ask_test(_on_test)


func _on_test(res: Dictionary) -> void:
	Settings.ai_enabled = _ai_toggle.button_pressed
	_test_button.disabled = false
	if res.ok:
		_show_test_result("连接成功（%.1f 秒）：%s" % [res.latency, str(res.data.get("msg", "ok"))], UiTheme.TEAL)
	else:
		_show_test_result("失败：" + str(res.error), UiTheme.RED)


func close() -> void:
	_store_ai()
	Settings.save_settings()
	Settings.apply()
	super()
