extends Enemy
## Bone archer: keeps its distance, shows a red aim line that locks just before the shot.

enum { MOVE, AIM }

const TOO_CLOSE := 80.0
const TOO_FAR := 150.0
const SHOT_RANGE := 220.0
const AIM_TIME := 0.75
const LOCK_TIME := 0.18      # the line stops tracking this long before the arrow flies
const LINE_LENGTH := 240.0
const VOLLEY_DEPTH := 4      # from this depth on, three arrows instead of one
const VOLLEY_STEP := 0.22

var _aim_dir := Vector2.RIGHT
var _strafe := 1.0
var _line: Line2D


func _configure() -> void:
	sheet = "archer"
	max_hp = 26.0
	speed = 46.0
	hit_offset = Vector2(0, -7)
	embers = Vector2i(2, 3)
	_pick_strafe()
	enter(MOVE, randf_range(1.2, 2.2))


func _build() -> void:
	_line = Line2D.new()
	_line.width = 1.0
	_line.default_color = Color(0.95, 0.25, 0.2, 0.0)
	_line.material = Fx.unshaded()
	_line.z_index = 5
	add_child(_line)


func _pick_strafe() -> void:
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> void:
	match state:
		MOVE:
			play("walk")
			_keep_distance(delta)
			if state_t <= 0.0 and to_player().length() < SHOT_RANGE and sees_player(true):
				enter(AIM, AIM_TIME)
		AIM:
			play("aim")
			desired = Vector2.ZERO
			var locked := state_t <= LOCK_TIME
			if not locked:
				_aim_dir = aim_at_player()
			_line.default_color = Color(1.0, 0.25, 0.2, 0.9 if locked else 0.35 + 0.25 * sin(state_t * 30.0))
			_line.points = PackedVector2Array([hit_offset, hit_offset + _aim_dir * LINE_LENGTH])
			if state_t <= 0.0:
				_loose()


## Circle the player at mid range; back off when crowded, close in when too far or out of sight.
func _keep_distance(delta: float) -> void:
	var offset := to_player()
	var dist := offset.length()
	if dist > TOO_FAR or not sees_player():
		steer_to(player().global_position, speed, delta)
	else:
		var side := offset.orthogonal().normalized() * -_strafe
		var dir := side
		if dist < TOO_CLOSE:
			dir = (-offset.normalized() * 1.2 + side * 0.5).normalized()
		desired = dir * speed
	if hit_wall():
		_strafe = -_strafe


func _loose() -> void:
	_line.points = PackedVector2Array()
	Sound.play("arrow", -4.0, 1.0, 0.1)
	var arrow_speed := 185.0 + depth_level * 8.0
	fan_shot("arrow", _aim_dir, 3 if depth_level >= VOLLEY_DEPTH else 1, VOLLEY_STEP, arrow_speed, 2.5)
	_pick_strafe()
	enter(MOVE, randf_range(1.6, 2.4))


func _on_death() -> void:
	_line.points = PackedVector2Array()
