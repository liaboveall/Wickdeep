class_name SpeechBubble
extends PanelContainer
## A speech bubble in the world (Wick at the campfire). Sits above `anchor` and fades by itself.

const CHARS_PER_LINE := 13
const FADE_TIME := 0.5

var anchor := Vector2.ZERO     # the bubble's bottom centre, in its parent's coordinates
var _label: Label
var _time_left := 0.0


func _init() -> void:
	theme = UiTheme.theme()
	add_theme_stylebox_override("panel", UiTheme.nine("bubble", 4, 3))
	material = Fx.unshaded()
	z_index = 30
	_label = UiTheme.label("", UiTheme.INK)
	add_child(_label)


## Show `text`; with no duration the bubble stays long enough to read it.
func say(text: String, duration := -1.0) -> void:
	_label.text = TextUtil.wrap(text, CHARS_PER_LINE)
	reset_size()
	modulate.a = 1.0
	position = (anchor - Vector2(size.x / 2.0, size.y)).round()
	_time_left = duration if duration > 0.0 else 7.0 + text.length() * 0.12


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		create_tween().tween_property(self, "modulate:a", 0.0, FADE_TIME)
