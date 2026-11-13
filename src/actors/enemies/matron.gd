extends Boss
## Boss 1: the Moss Matron. Leaps at the player (landing spot telegraphed), slams out shockwave
## rings, spits volleys, and splits off slimes at 2/3 and 1/3 health.

enum { INTRO, WAIT, CROUCH, JUMP, SPIT }

const INTRO_TIME := 1.2
const JUMP_HEIGHT := 46.0
const LAND_HIT_RADIUS := 24.0
const SPIT_EVERY := 3           # every third action is a spit volley instead of a jump
const SPIT_INTERVAL := 0.32
const SPLIT_SLIMES := 2

var _actions := 0
var _jump_from := Vector2.ZERO
var _jump_to := Vector2.ZERO
var _jump_time := 0.75
var _spits_left := 0


func _configure() -> void:
	sheet = "matron"
	max_hp = 650.0
	speed = 0.0
	accel = 900.0
	hit_radius = 15.0
	hit_offset = Vector2(0, -12)
	sprite_offset = Vector2(0, -16)
	shadow_width = 34
	embers = Vector2i(25, 30)
	enter(INTRO, INTRO_TIME)


func _untouchable() -> bool:
	return state == JUMP


func _ai(delta: float) -> void:
	match state:
		INTRO:
			play("idle")
			desired = Vector2.ZERO
			if state_t <= 0.0:
				_next_action()
		WAIT:
			play("idle")
			brake(400.0, delta)
			if state_t <= 0.0:
				_next_action()
		CROUCH:
			play("crouch")
			desired = Vector2.ZERO
			if state_t <= 0.0:
				_start_jump()
		JUMP:
			play("jump")
			var k := 1.0 - state_t / _jump_time
			global_position = _jump_from.lerp(_jump_to, k)
			sprite.position.y = sprite_offset.y - sin(k * PI) * JUMP_HEIGHT
			lunge(Vector2.ZERO)
			if state_t <= 0.0:
				_land()
		SPIT:
			play("crouch")
			desired = Vector2.ZERO
			if state_t <= 0.0:
				_spit()


func _next_action() -> void:
	_actions += 1
	if _actions % SPIT_EVERY == 0:
		_spits_left = 3 if phase == 3 else 2
		enter(SPIT, 0.5)
	else:
		enter(CROUCH, 0.55 if phase == 1 else 0.38)


func _start_jump() -> void:
	_jump_time = 0.6 if phase == 3 else 0.75
	enter(JUMP, _jump_time)
	_jump_from = global_position
	var room := arena()
	var target := player().global_position + player().velocity * 0.3
	target.x = clampf(target.x, room.position.x + 24, room.end.x - 24)
	target.y = clampf(target.y, room.position.y + 24, room.end.y - 12)
	_jump_to = target
	# in the air: no touch damage, and walls do not stop the arc
	contact_damage = 0
	collision_mask = 0
	Sound.play("slime_hop", 0.0, 0.5)
	world.telegraph(_jump_to, 22.0, _jump_time, Color(0.55, 0.85, 0.3))


func _land() -> void:
	sprite.position.y = sprite_offset.y
	contact_damage = 1
	collision_mask = PhysicsLayers.WORLD
	Sound.play("boss_slam")
	Juice.shake(0.75)
	Fx.ring(world.fx, global_position, 70, Color("#a9c46a"), 0.4, 3)
	for k in 6:
		Fx.dust(world.fx, global_position + Vector2.from_angle(k * TAU / 6.0) * 16.0, 1.6)
	ring_shot("orb_green", [14, 16, 20][phase - 1], 84.0, randf() * TAU)
	var p := player()
	if p.can_be_hit() and p.global_position.distance_to(global_position) < LAND_HIT_RADIUS:
		p.hurt(1, kind, global_position)
	var rest: float = [0.9, 0.6, 0.3][phase - 1]
	# in the last phase every other landing chains straight into the next jump
	if phase == 3 and _actions % 2 == 1:
		rest = 0.1
	enter(WAIT, rest)


func _spit() -> void:
	_spits_left -= 1
	fan_shot("orb_green", aim_at_player(), 7 if phase == 3 else 5, 0.2, 125.0)
	Sound.play("enemy_shoot", -2.0, 0.6)
	if _spits_left > 0:
		state_t = SPIT_INTERVAL
	else:
		enter(WAIT, 0.8)


## A new phase: shrug off damage for a moment and shed a couple of slimes.
func _on_phase(_new_phase: int) -> void:
	stagger(1.2, 400.0)
	Juice.shake(0.6)
	Fx.ring(world.fx, center(), 90, Color("#a9c46a"), 0.5, 3)
	for k in SPLIT_SLIMES:
		var angle := k * PI + randf() * 0.4
		var pos := global_position + Vector2.from_angle(angle) * 30.0
		if world.grid.is_solid_at(pos):
			pos = global_position
		world.spawn_enemy("slime", pos, 2).push(Vector2.from_angle(angle) * 160.0)
	enter(WAIT, 1.0)
