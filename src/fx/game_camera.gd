class_name GameCamera
extends Camera2D
## Follows the player with a lead towards the aim point, plus trauma-based screen shake.

var target: Node2D
var lead := Vector2.ZERO
var trauma := 0.0
var follow_speed := 9.0
var focus_override := Vector2.INF   # when set, the camera looks here instead (boss intros)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Juice.shake_requested.connect(add_trauma)
	make_current()


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func snap_to_target() -> void:
	if target:
		global_position = target.global_position + lead


func _process(delta: float) -> void:
	var goal := global_position
	if focus_override != Vector2.INF:
		goal = focus_override
	elif is_instance_valid(target):
		goal = target.global_position + lead
	global_position = global_position.lerp(goal, 1.0 - exp(-delta * follow_speed))
	trauma = maxf(0.0, trauma - delta * 1.6)
	var s := trauma * trauma * 8.0
	offset = Vector2(round(randf_range(-s, s)), round(randf_range(-s, s)))
