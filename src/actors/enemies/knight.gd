extends Enemy
## Crypt knight: slow, heavy. Flashes, then charges in a straight line; stunned if it hits a wall.

enum { WALK, WINDUP, CHARGE, STUNNED }

const CHARGE_RANGE := 170.0
const WINDUP_TIME := 0.7
const AIM_LOCK := 0.15          # the charge direction is fixed this long before it starts
const CHARGE_TIME := 1.1
const CHARGE_SPEED := 265.0
const STUN_TIME := 1.3

var _charge := Vector2.ZERO
var _stars: Node2D


func _configure() -> void:
	sheet = "knight"
	max_hp = 75.0
	speed = 34.0
	accel = 400.0
	knock_resist = 0.25
	hit_radius = 7.0
	hit_offset = Vector2(0, -9)
	sprite_offset = Vector2(0, -10)
	shadow_width = 14
	embers = Vector2i(3, 5)
	enter(WALK, randf_range(1.0, 2.0))


func _ai(delta: float) -> void:
	match state:
		WALK:
			play("walk")
			steer_to(player().global_position, speed, delta)
			if state_t <= 0.0 and to_player().length() < CHARGE_RANGE and sees_player():
				enter(WINDUP, WINDUP_TIME)
				Sound.play("knight_charge", -4.0)
		WINDUP:
			play("windup")
			desired = Vector2.ZERO
			flicker(16.0, 0.7)
			sprite.position.x = randf_range(-1, 1)   # shake with effort
			if state_t > AIM_LOCK:
				_charge = to_player().normalized()
			if state_t <= 0.0:
				sprite.position.x = 0
				enter(CHARGE, CHARGE_TIME)
		CHARGE:
			play("charge")
			lunge(_charge * CHARGE_SPEED)
			if int(state_t * 30) % 3 == 0:
				Fx.dust(world.fx, global_position)
			if hit_wall():
				_crash()
			elif state_t <= 0.0:
				enter(WALK, randf_range(1.6, 2.4))


## Ran into a wall: dazed for a moment, and taking extra damage while it lasts.
func _crash() -> void:
	enter(STUNNED)
	stun(STUN_TIME)
	play("stun")
	Sound.play("stun")
	Sound.play("boss_slam", -8.0, 1.4)
	Juice.shake(0.35)
	_show_stars(true)


func _on_stun_end() -> void:
	_show_stars(false)
	enter(WALK, randf_range(1.4, 2.2))


func _show_stars(on: bool) -> void:
	if on and _stars == null:
		_stars = Node2D.new()
		_stars.position = Vector2(0, -22)
		for k in 3:
			var star := Sprite2D.new()
			star.texture = SpriteLib.region("shard", "spin")
			star.position = Vector2.from_angle(k * TAU / 3.0) * 6.0
			star.material = Fx.unshaded()
			_stars.add_child(star)
		add_child(_stars)
		_stars.create_tween().set_loops().tween_property(_stars, "rotation", TAU, TAU / 4.0).as_relative()
	elif not on and _stars:
		_stars.queue_free()
		_stars = null
