class_name ChatPanel
extends PanelContainer
## Conversation log with typewriter text, a free-text input and quick-reply buttons.
## Used for talking to Wick and haggling with Granny.

signal submitted(text: String)

const PLAYER_NAME := "你"
const PORTRAIT_SIZE := Vector2(80, 80)
const MAX_INPUT_LENGTH := 80

var speaker_name := ""
var speaker_color := UiTheme.AMBER
var talk_sound := "talk_wick"
var portrait: Texture2D

var input: LineEdit
var send_button: Button
var quick_row: HFlowContainer
var status: Label
var _log: RichTextLabel
var _typewriter: Typewriter
var _busy := false
var _busy_time := 0.0
var _free_text := true     # false when no model is configured: only quick replies work


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var columns := Ui.hbox(8)
	add_child(columns)
	columns.add_child(_build_speaker())
	var right := Ui.vbox(4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0, 92)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.selection_enabled = false
	right.add_child(_log)
	_typewriter = Typewriter.new(_log)
	_typewriter.blip = talk_sound
	add_child(_typewriter)
	status = UiTheme.label("", UiTheme.DIM)
	# a long note (an error message, say) wraps onto a second line instead of widening the panel
	status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	right.add_child(status)
	quick_row = HFlowContainer.new()
	quick_row.add_theme_constant_override("h_separation", 4)
	quick_row.add_theme_constant_override("v_separation", 4)
	right.add_child(quick_row)
	right.add_child(_build_input_row())


func _build_speaker() -> Control:
	var box := Ui.vbox(4)
	var picture := TextureRect.new()
	picture.texture = portrait
	picture.custom_minimum_size = PORTRAIT_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	box.add_child(picture)
	box.add_child(Ui.centered_label(speaker_name, speaker_color))
	return box


func _build_input_row() -> Control:
	var row := Ui.hbox(4)
	input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.max_length = MAX_INPUT_LENGTH
	input.placeholder_text = "说点什么……（回车发送）"
	input.text_submitted.connect(_submit)
	row.add_child(input)
	send_button = Button.new()
	send_button.text = "发送"
	send_button.custom_minimum_size = Vector2(44, 0)
	send_button.pressed.connect(func() -> void: _submit(input.text))
	row.add_child(send_button)
	return row


func _process(delta: float) -> void:
	if _busy:
		_busy_time += delta
		status.text = "%s 正在想%s" % [speaker_name, ".".repeat(1 + int(_busy_time * 3.0) % 3)]


# ------------------------------------------------------------------ the log
func add_line(who: String, text: String, color: Color, typed := true) -> void:
	var before := _log.get_total_character_count()
	if _log.get_parsed_text() != "":
		_log.append_text("\n")
	_log.append_text("[color=#%s]%s：[/color]%s" % [color.to_html(false), who, TextUtil.escape_bbcode(text)])
	if typed:
		_typewriter.start(before + 1)
	else:
		_typewriter.skip()


## The character speaks (typed out).
func say(text: String) -> void:
	add_line(speaker_name, text, speaker_color, true)


func player_said(text: String) -> void:
	add_line(PLAYER_NAME, text, UiTheme.TEAL, false)


## Show an earlier conversation again, without typing it out.
func replay(messages: Array) -> void:
	for message: Dictionary in messages:
		if Dialogue.is_user(message):
			player_said(Dialogue.spoken(message))
		else:
			add_line(speaker_name, Dialogue.spoken(message), speaker_color, false)


func skip_typing() -> void:
	_typewriter.skip()


# ------------------------------------------------------------------ input state
## While the character is "thinking" (a request is out), nothing can be sent.
func set_busy(busy: bool) -> void:
	_busy = busy
	_busy_time = 0.0
	set_input_enabled(not busy)
	if not busy:
		status.text = ""


func set_input_enabled(enabled: bool) -> void:
	input.editable = enabled and _free_text
	send_button.disabled = not input.editable
	for button in quick_row.get_children():
		if button is Button:
			button.disabled = not enabled


## Turn free text off for good (no model configured); quick replies stay available.
func disable_free_text(placeholder: String) -> void:
	_free_text = false
	input.editable = false
	send_button.disabled = true
	input.placeholder_text = placeholder


func set_status(text: String) -> void:
	status.text = text


func add_quick(label_text: String, on_press: Callable) -> Button:
	var b := Ui.button(label_text, on_press, 0)
	quick_row.add_child(b)
	return b


func focus_input() -> void:
	if input.editable:
		input.grab_focus.call_deferred()


func _submit(text: String) -> void:
	text = text.strip_edges()
	if text == "" or _busy or not input.editable:
		return
	input.text = ""
	submitted.emit(text)
