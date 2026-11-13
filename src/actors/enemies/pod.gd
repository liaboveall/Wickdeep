extends Enemy
## Spore pod: rooted turret. Opens its mouth (telegraph) then spits a spread of spores.

enum { CLOSED, OPEN }

const OPEN_TIME := 0.45
const SPREAD_STEP := 0.26
const BIG_SPREAD_DEPTH := 3     # from this depth on, five spores instead of three


func _configure() -> void:
	sheet = "pod"
	max_hp = 40.0
	speed = 0.0
	knock_resist = 0.0
	hit_offset = Vector2(0, -7)
	hit_radius = 7.0
	shadow_width = 14
	embers = Vector2i(2, 3)
	face_player = false
	enter(CLOSED, randf_range(1.0, 2.2))


func _ai(_delta: float) -> void:
	desired = Vector2.ZERO
	match state:
		CLOSED:
			play("idle")
			if state_t <= 0.0 and sees_player(true):
				enter(OPEN, OPEN_TIME)
		OPEN:
			play("open")
			sprite.scale = Vector2.ONE * (1.0 + 0.12 * sin(state_t * 40.0))   # quiver before spitting
			if state_t <= 0.0:
				sprite.scale = Vector2.ONE
				fan_shot("orb_green", aim_at_player(), 5 if depth_level >= BIG_SPREAD_DEPTH else 3, SPREAD_STEP,
					105.0 + depth_level * 5.0)
				Sound.play("enemy_shoot", -4.0, 0.8, 0.1)
				enter(CLOSED, randf_range(2.0, 2.8))
