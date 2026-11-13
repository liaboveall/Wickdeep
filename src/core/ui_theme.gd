class_name UiTheme
extends RefCounted
## Builds the pixel UI theme in code: SimSun's embedded 12px bitmap glyphs for Chinese
## (crisp, no antialiasing) plus the generated 5x7 pixel font for numbers.

const CREAM := Color("#fff3cf")
const GOLD := Color("#ffd978")
const AMBER := Color("#f5b84c")
const EMBER := Color("#e08a3c")
const MIST := Color("#a49bb6")
const FOG := Color("#d8d0e2")
const RED := Color("#d8503f")
const TEAL := Color("#9cd3dc")
const INK := Color("#1c1626")
const DIM := Color("#766d8e")

static var _theme: Theme
static var _font: Font
static var _pixel: Font
static var _pixel_o: Font


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["SimSun", "NSimSun", "Microsoft YaHei", "PingFang SC",
			"Hiragino Sans GB", "Noto Sans CJK SC", "WenQuanYi Zen Hei", "sans-serif"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.disable_embedded_bitmaps = false
		f.hinting = TextServer.HINTING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		f.generate_mipmaps = false
		f.allow_system_fallback = true
		_font = f
	return _font


static func pixel_font(outlined := false) -> Font:
	if outlined:
		if _pixel_o == null:
			_pixel_o = load("res://assets/sprites/pixel5x7_o.fnt")
		return _pixel_o
	if _pixel == null:
		_pixel = load("res://assets/sprites/pixel5x7.fnt")
	return _pixel


static func nine(tex_name: String, margin := 6, content := 4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = SpriteLib.ui(tex_name)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content + 2
	sb.content_margin_right = content + 2
	sb.content_margin_top = content
	sb.content_margin_bottom = content
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 12
	var panel := nine("panel", 6, 6)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "PopupPanel", panel)
	for state in ["normal", "focus"]:
		t.set_stylebox(state, "Button", nine("btn", 4, 3))
	t.set_stylebox("hover", "Button", nine("btn_hover", 4, 3))
	t.set_stylebox("pressed", "Button", nine("btn_press", 4, 3))
	t.set_stylebox("disabled", "Button", nine("btn_disabled", 4, 3))
	var focus := nine("btn_hover", 4, 3)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_color("font_color", "Label", CREAM)
	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_constant("line_separation", "RichTextLabel", 2)
	t.set_constant("line_spacing", "Label", 2)
	var edit := StyleBoxFlat.new()
	edit.bg_color = View.BACKDROP
	edit.border_color = Color("#5c5246")
	edit.set_border_width_all(1)
	edit.content_margin_left = 4
	edit.content_margin_right = 4
	edit.content_margin_top = 3
	edit.content_margin_bottom = 3
	var edit_focus := edit.duplicate() as StyleBoxFlat
	edit_focus.border_color = AMBER
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit_focus)
	t.set_stylebox("read_only", "LineEdit", edit)
	t.set_color("font_color", "LineEdit", CREAM)
	t.set_color("font_placeholder_color", "LineEdit", DIM)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color("#6e3f8a"))
	# sliders
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#262036")
	track.border_color = Color("#524a6c")
	track.set_border_width_all(1)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = AMBER
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _grabber_texture()
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)
	# check boxes
	t.set_icon("checked", "CheckBox", _check_texture(true))
	t.set_icon("unchecked", "CheckBox", _check_texture(false))
	t.set_color("font_color", "CheckBox", CREAM)
	t.set_color("font_hover_color", "CheckBox", GOLD)
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	# scroll bars (chat logs)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color("#524a6c")
	sc.content_margin_left = 2
	sc.content_margin_right = 2
	t.set_stylebox("grabber", "VScrollBar", sc)
	t.set_stylebox("grabber_highlight", "VScrollBar", sc)
	t.set_stylebox("grabber_pressed", "VScrollBar", sc)
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color("#1c1626")
	sbg.content_margin_left = 2
	sbg.content_margin_right = 2
	t.set_stylebox("scroll", "VScrollBar", sbg)
	_theme = t
	return t


static func _grabber_texture() -> Texture2D:
	var img := Image.create(6, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color("#120e18"))
	for y in range(1, 9):
		for x in range(1, 5):
			img.set_pixel(x, y, GOLD if y < 3 else AMBER)
	return ImageTexture.create_from_image(img)


static func _check_texture(on: bool) -> Texture2D:
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color("#120e18"))
	for y in range(1, 9):
		for x in range(1, 9):
			img.set_pixel(x, y, Color("#5c5246") if (x == 1 or y == 1 or x == 8 or y == 8) else Color("#262036"))
	if on:
		for y in range(3, 7):
			for x in range(3, 7):
				img.set_pixel(x, y, AMBER)
	return ImageTexture.create_from_image(img)


## Label helper.
static func label(text: String, color := CREAM, size := 12) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if size != 12:
		l.add_theme_font_size_override("font_size", size)
	return l


## Give a label a dark outline so it stays readable over the game world.
static func outlined(l: Label, size := 2, color := INK) -> Label:
	l.add_theme_color_override("font_outline_color", color)
	l.add_theme_constant_override("outline_size", size)
	return l


## Large heading: the crisp 12px bitmap glyphs doubled (pixel-perfect), centred in `width`.
static func big_label(text: String, color := GOLD, width := 640.0) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(width, 30)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := outlined(label(text, color))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(width / 2.0, 15)
	l.scale = Vector2(2, 2)
	holder.add_child(l)
	return holder


static func pixel_label(text: String, color := CREAM, outlined := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", pixel_font(outlined))
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	return l
