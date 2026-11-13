extends Node
## Game-feel helpers: hit-stop and camera shake requests.

signal shake_requested(amount: float)

var _stop_until := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Slow the game almost to a halt for a few real-time milliseconds (impact emphasis).
func hitstop(seconds: float, scale := 0.05) -> void:
	if get_tree().paused:
		return
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if until <= _stop_until:
		return
	_stop_until = until
	Engine.time_scale = scale


func _process(_delta: float) -> void:
	if _stop_until > 0 and Time.get_ticks_msec() >= _stop_until:
		_stop_until = 0
		Engine.time_scale = 1.0


func shake(amount: float) -> void:
	shake_requested.emit(amount * Settings.screen_shake)


func reset() -> void:
	Engine.time_scale = 1.0
	_stop_until = 0
