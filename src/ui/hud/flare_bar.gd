class_name FlareBar
extends Control
## Small bar showing the flare charge; it blinks once the flare is ready.

const FRAME := Color("#120e18")
const TROUGH := Color("#262036")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, FRAME)
	draw_rect(area.grow(-1), TROUGH)
	var charge := clampf(Run.flare / Run.FLARE_MAX, 0.0, 1.0)
	var color := UiTheme.EMBER
	if Run.flare_ready():
		color = UiTheme.CREAM if int(Time.get_ticks_msec() / 150.0) % 2 == 0 else UiTheme.GOLD
	draw_rect(Rect2(1, 1, (size.x - 2) * charge, size.y - 2), color)
