class_name Ui
extends RefCounted
## Builders for the pieces every screen is made of. The whole UI is assembled in code, so these
## keep the screens down to "what goes where" (colours and fonts are in UiTheme).


## A button that clicks and ticks like every other button in the game.
## min_width 0 lets it shrink to its text.
static func button(text: String, on_press: Callable, min_width := 120) -> Button:
	var b := Button.new()
	b.text = text
	if min_width > 0:
		b.custom_minimum_size = Vector2(min_width, 20)
	add_sounds(b)
	b.pressed.connect(on_press)
	return b


## Select / hover / focus sounds for any button-like control.
static func add_sounds(b: BaseButton) -> void:
	b.pressed.connect(Sound.play.bind("ui_select"))
	b.mouse_entered.connect(Sound.play.bind("ui_move", -6.0))
	b.focus_entered.connect(Sound.play.bind("ui_move", -8.0))


static func hbox(separation := 4) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func vbox(separation := 4) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func grid(columns: int, h_separation := 8, v_separation := 4) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", h_separation)
	g.add_theme_constant_override("v_separation", v_separation)
	return g


## Wrap a control so it sits in the middle of whatever container it is added to.
static func center(node: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(node)
	return c


static func centered_label(text: String, color := UiTheme.CREAM, size := 12) -> Label:
	var l := UiTheme.label(text, color, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Section heading inside a panel.
static func heading(text: String) -> Label:
	return centered_label(text, UiTheme.GOLD, 16)


## A line of text centred across the whole screen at height `y`.
static func screen_line(text: String, y: float, color := UiTheme.CREAM, size := 12) -> Label:
	var l := centered_label(text, color, size)
	l.position = Vector2(0, y)
	l.size = Vector2(View.W, size + 2)
	return l


## Text that wraps inside `width` pixels. CJK text has no spaces, so it may break anywhere.
static func wrapped_label(text: String, color: Color, width: float) -> Label:
	var l := UiTheme.label(text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.custom_minimum_size = Vector2(width, 0)
	return l


## A texture shown at its own size.
static func image(texture: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func relic_icon(id: String) -> TextureRect:
	return image(SpriteLib.icon(id))


static func fill_parent(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c
