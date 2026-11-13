extends Enemy
## Wisp caster: drifts at mid range, casts slow rings of violet orbs, blinks away when crowded.

enum { DRIFT, CAST, BLINK }

const PERSONAL_SPACE := 42.0
const CAST_TIME := 0.55
const BLINK_TIME := 0.3
const RING_SPEED := 70.0
const ELDER_DEPTH := 4          # from this depth on: denser rings, and an echo ring in the gaps
const ECHO_DELAY := 0.35
const GLOW := 0.7

var _goal := Vector2.ZERO
var _goal_t := 0.0
var _echo_t := -1.0             # countdown to the second, offset ring
var _ring_angle := 0.0
var _light: PointLight2D


func _configure() -> void:
	sheet = "wisp"
	max_hp = 34.0
	speed = 34.0
	accel = 200.0
	hit_offset = Vector2(0, -9)
	sprite_offset = Vector2(0, -11)
	flying = true
	embers = Vector2i(2, 4)
	enter(DRIFT, randf_range(1.4, 2.4))


func _build() -> void:
	_light = Lights.make(Color(0.75, 0.45, 1.0), 40.0, GLOW)
	_light.position = Vector2(0, -9)
	add_child(_light)


func _ai(delta: float) -> void:
	hover(3.33, 1.5)
	_tick_echo(delta)
	_goal_t -= delta
	match state:
		DRIFT:
			play("float")
			if _goal_t <= 0.0:
				_goal_t = 1.5
				_goal = player().global_position + Vector2.from_angle(randf() * TAU) * randf_range(85, 125)
			steer_to(_goal, speed, delta)
			if to_player().length() < PERSONAL_SPACE and state_t > 0.4:
				enter(BLINK, BLINK_TIME)
			elif state_t <= 0.0:
				enter(CAST, CAST_TIME)
				Sound.play("spawn", -10.0, 1.6)
		CAST:
			play("cast")
			desired = Vector2.ZERO
			_light.energy = GLOW + (CAST_TIME - state_t) * 2.0
			if state_t <= 0.0:
				_cast_ring()
				enter(DRIFT, randf_range(2.4, 3.2))
		BLINK:
			desired = Vector2.ZERO
			modulate.a = maxf(0.0, state_t / BLINK_TIME)
			if state_t <= 0.0:
				_teleport()
				enter(DRIFT, 0.9)


func _cast_ring() -> void:
	var elder := depth_level >= ELDER_DEPTH
	_ring_angle = randf() * TAU
	ring_shot("orb_violet", 12 if elder else 8, RING_SPEED + depth_level * 4.0, _ring_angle)
	if elder:
		_echo_t = ECHO_DELAY
	Sound.play("enemy_shoot", -3.0, 0.7)
	_light.energy = GLOW


func _tick_echo(delta: float) -> void:
	if _echo_t <= 0.0:
		return
	_echo_t -= delta
	if _echo_t <= 0.0:
		ring_shot("orb_violet", 12, RING_SPEED, _ring_angle + PI / 12.0)
		Sound.play("enemy_shoot", -5.0, 0.75)


## Reappear somewhere at casting distance with a clear view of the player.
func _teleport() -> void:
	for attempt in 12:
		var spot := player().global_position + Vector2.from_angle(randf() * TAU) * randf_range(90, 130)
		if not world.grid.is_solid_at(spot) and world.grid.line_of_sight(spot, player().global_position):
			global_position = spot
			break
	modulate.a = 1.0
	Fx.burst(world.fx, center(), Color("#a466c4"), 10, 60, 0.4)
