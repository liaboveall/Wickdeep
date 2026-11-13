extends Enemy
## Ash slime: waits, crouches (telegraph), then leaps at the player.

enum { IDLE, CROUCH, LEAP }

const CROUCH_TIME := 0.42
const LEAP_TIME := 0.42
const LEAP_RANGE := 80.0
const LEAD := 0.2            # seconds of player movement the leap anticipates

var _leap := Vector2.ZERO


func _configure() -> void:
	sheet = "slime"
	max_hp = 22.0
	speed = 0.0
	accel = 900.0
	hit_radius = 6.0
	hit_offset = Vector2(0, -4)
	enter(IDLE, randf_range(0.4, 1.0))


func danger_radius() -> float:
	return 60.0 if state == CROUCH else 0.0


func _ai(delta: float) -> void:
	match state:
		IDLE:
			play("idle")
			brake(300.0, delta)
			if state_t <= 0.0:
				enter(CROUCH, CROUCH_TIME)
		CROUCH:
			play("crouch")
			desired = Vector2.ZERO
			if state_t <= 0.0:
				var target := player().global_position + player().velocity * LEAD
				_leap = (target - global_position).limit_length(LEAP_RANGE) / LEAP_TIME
				enter(LEAP, LEAP_TIME)
				Sound.play("slime_hop", -8.0, 1.0, 0.15)
		LEAP:
			play("jump")
			lunge(_leap)
			if state_t <= 0.0:
				enter(IDLE, randf_range(0.55, 1.1))
				Fx.dust(world.fx, global_position + Vector2(-4, 0))
				Fx.dust(world.fx, global_position + Vector2(4, 0))
