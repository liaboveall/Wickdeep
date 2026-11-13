extends Enemy
## Soot bat: erratic circling flight, then a telegraphed swoop through the player's position.

enum { CIRCLE, TELL, SWOOP }

const ORBIT_RADIUS := 58.0
const TELL_TIME := 0.45
const SWOOP_TIME := 0.5
const SWOOP_SPEED := 215.0

var _orbit := randf() * TAU
var _turn := 1.0             # orbit direction, flipped after every swoop
var _swoop := Vector2.ZERO


func _configure() -> void:
	sheet = "bat"
	max_hp = 14.0
	speed = 70.0
	accel = 420.0
	hit_radius = 6.0
	hit_offset = Vector2(0, -10)
	sprite_offset = Vector2(0, -14)
	shadow_width = 8
	flying = true
	embers = Vector2i(1, 2)
	_turn = 1.0 if randf() < 0.5 else -1.0
	enter(CIRCLE, randf_range(1.5, 2.8))


func _ai(delta: float) -> void:
	hover(6.25, 2.0)
	match state:
		CIRCLE:
			_orbit += delta * 1.6 * _turn
			steer_to(player().global_position + Vector2.from_angle(_orbit) * ORBIT_RADIUS, speed, delta)
			if state_t <= 0.0 and sees_player():
				enter(TELL, TELL_TIME)
		TELL:
			brake(600.0, delta)
			flicker(20.0, 0.6)
			if state_t <= 0.0:
				_swoop = to_player().normalized() * SWOOP_SPEED
				enter(SWOOP, SWOOP_TIME)
		SWOOP:
			lunge(_swoop)
			if state_t <= 0.0 or hit_wall():
				_turn = -_turn
				enter(CIRCLE, randf_range(1.8, 3.0))
