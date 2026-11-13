class_name Player
extends CharacterBody2D
## The lamplighter. Movement with acceleration, dash with i-frames, aimed ember bolts,
## the "flare" burst, orbiting motes, and all the hit feedback.

signal damaged          # took a hit that got through
signal died             # the death animation has finished

const AIM_ORIGIN := Vector2(0, -7)     # where bolts leave from, relative to the feet
const HIT_CENTER := Vector2(0, -5)     # middle of the body, for things aiming at the player
const HIT_RADIUS := 4.0

const ACCELERATION := 1300.0
const BRAKING := 1500.0
const KNOCKBACK_DECAY := 900.0
const DASH_TIME := 0.16
const DASH_SPEED := 300.0
const DASH_GRACE := 0.06               # invulnerability that outlasts the dash itself
const DASH_HIT_REACH := 12.0
const HURT_IFRAMES := 1.0
const REVIVE_IFRAMES := 2.0
const SHADE_IFRAMES := 0.8
const HURT_KNOCKBACK := 170.0
const RECOIL := 10.0
const LIGHT_RADIUS := 175.0
const LIGHT_AT_ZERO_HP := 0.72         # the lantern shrinks as health drops
const CAMERA_LEAD := 34.0
const FOOTSTEP_INTERVAL := 0.28
const DEATH_TIME := 1.6

const FLARE_RADIUS := 100.0
const FLARE_BULLET_RADIUS := 120.0
const FLARE_DAMAGE := 40.0
const FLARE_DAMAGE_FREE := 25.0        # the warden bell's automatic flare is weaker
const FLARE_PUSH := 240.0

const MOTE_ORBIT := 22.0
const MOTE_DAMAGE := 8.0
const MOTE_HIT_INTERVAL := 0.4

var world: World
var input: PlayerInput
var aim := Vector2.RIGHT
var facing := 1.0
var combat := true           # false in the camp: no shooting, no flare
var dead := false
var god := false             # test flag: never takes damage
var light_mult := 1.0        # the Snuffer squeezes this
var shade_ready := true      # glass shade: blocks the first hit in each room

var sprite: AnimatedSprite2D
var lantern: AnimatedSprite2D
var lantern_light: Lights.Flicker
var _flash_mat: ShaderMaterial
var _clock := 0.0
var _fire_cd := 0.0
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_hit := {}          # enemies already hit by this dash
var _afterimage_cd := 0.0
var _iframes := 0.0
var _blink := 0.0
var _flash := 0.0
var _knock := Vector2.ZERO
var _step_cd := 0.0
var _motes: Array[Node2D] = []
var _mote_angle := 0.0
var _mote_ready_at := {}     # enemy instance id -> clock time it can be burnt again


func _ready() -> void:
	ActorGfx.setup_body(self, PhysicsLayers.PLAYER)
	add_child(ActorGfx.shadow(12))
	sprite = SpriteLib.make_sprite("player", "idle")
	sprite.position = Vector2(0, -8)
	_flash_mat = ActorGfx.flash_material()
	sprite.material = _flash_mat
	add_child(sprite)
	lantern = SpriteLib.make_sprite("lantern", "burn")
	lantern.material = Fx.unshaded()
	add_child(lantern)
	lantern_light = Lights.flicker(Color(1.0, 0.78, 0.55), LIGHT_RADIUS, 1.05)
	add_child(lantern_light)
	if input == null:
		input = PlayerInput.Human.new()
	Run.changed.connect(_sync_motes)
	_sync_motes()


func can_be_hit() -> bool:
	return not dead and not god and _iframes <= 0.0 and _dash_t <= 0.0


func is_dashing() -> bool:
	return _dash_t > 0.0


func is_armed() -> bool:
	return combat and world.combat_enabled


func _physics_process(delta: float) -> void:
	if dead:
		return
	_clock += delta
	input.update(self, delta)
	_update_aim()
	_tick_timers(delta)
	_move(delta)
	if is_armed():
		_fight()
	world.update_interaction(self)
	if input.interact:
		world.try_interact()
	_lead_camera(delta)
	_animate(delta)
	_update_motes(delta)


func _update_aim() -> void:
	if input.aim.length() > 0.1:
		aim = input.aim.normalized()
	if absf(aim.x) > 0.15:
		facing = signf(aim.x)
	sprite.flip_h = facing < 0.0


func _tick_timers(delta: float) -> void:
	_fire_cd -= delta
	_dash_cd -= delta
	_iframes -= delta
	_blink -= delta
	_flash = maxf(0.0, _flash - delta * 6.0)
	_flash_mat.set_shader_parameter("flash", _flash)


# ------------------------------------------------------------------ movement
func _move(delta: float) -> void:
	if input.dash and _dash_cd <= 0.0 and _dash_t <= 0.0:
		_start_dash()
	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _dash_dir * DASH_SPEED
		_afterimage_cd -= delta
		if _afterimage_cd <= 0.0:
			_afterimage_cd = 0.03
			Fx.afterimage(world.fx, sprite, Color(0.55, 0.85, 1.0, 0.55))
		if Run.stats.dash_damage > 0.0:
			_dash_through_enemies()
	else:
		var target := input.move.limit_length(1.0) * Run.stats.move_speed
		var rate := ACCELERATION if target.length() > 1.0 else BRAKING
		velocity = velocity.move_toward(target, rate * delta)
	# knockback rides on top of the walking velocity for one move, then decays on its own
	velocity += _knock
	_knock = _knock.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()
	velocity -= _knock


func _start_dash() -> void:
	_dash_dir = input.move.normalized() if input.move.length() > 0.1 else aim
	_dash_t = DASH_TIME
	_dash_cd = Run.stats.dash_cooldown
	_iframes = maxf(_iframes, DASH_TIME + DASH_GRACE)
	_dash_hit.clear()
	Sound.play("dash", -3.0, 1.0, 0.08)
	Fx.dust(world.fx, global_position, 1.5)


## Shadow step: dashing through enemies hurts each of them once.
func _dash_through_enemies() -> void:
	for e in world.enemies:
		if e.dead or _dash_hit.has(e.get_instance_id()):
			continue
		if e.global_position.distance_to(global_position) < DASH_HIT_REACH + e.hit_radius:
			_dash_hit[e.get_instance_id()] = true
			e.take_damage(Run.stats.dash_damage, _dash_dir)


func _lead_camera(delta: float) -> void:
	if world.camera == null:
		return
	var want := Vector2.ZERO
	if is_armed():
		want = ((input.aim_point - global_position) * 0.2).limit_length(CAMERA_LEAD)
	world.camera.lead = world.camera.lead.lerp(want, 1.0 - exp(-delta * 6.0))


# ------------------------------------------------------------------ fighting
func _fight() -> void:
	if input.shoot and _fire_cd <= 0.0 and _dash_t <= 0.0:
		_shoot()
	if input.flare:
		if Run.flare_ready():
			release_flare(false)
		else:
			Sound.play("deny", -8.0)


func _shoot() -> void:
	var stats := Run.stats
	_fire_cd = stats.fire_interval
	var spread := deg_to_rad(stats.spread)
	var origin := global_position + lantern.position
	for i in stats.projectiles:
		var angle := aim.angle() + (i - (stats.projectiles - 1) / 2.0) * spread \
			+ deg_to_rad(randf_range(-stats.inaccuracy, stats.inaccuracy))
		world.add_projectile(Projectile.bolt(stats, origin, angle))
	Sound.play("shoot_heavy" if stats.bolt_scale > 1.2 else "shoot", -7.0, 1.0, 0.07)
	_knock -= aim * RECOIL


## Burst that damages and pushes nearby enemies and wipes their bullets.
## `free` flares (warden bell) cost no charge and hit a little softer.
func release_flare(free: bool) -> void:
	if not free:
		Run.spend_flare()
	var center := global_position + Vector2(0, -6)
	Sound.play("flare")
	Juice.shake(0.5)
	Fx.ring(world.fx, center, 100, UiTheme.GOLD, 0.45, 3)
	Fx.ring(world.fx, center, 70, UiTheme.EMBER, 0.35, 2)
	Fx.light_flash(world.fx, center, Color(1.0, 0.8, 0.45), 2.0, 1.6, 0.5)
	Fx.burst(world.fx, center, UiTheme.AMBER, 24, 160, 0.5, 2.0)
	var damage := FLARE_DAMAGE_FREE if free else FLARE_DAMAGE
	for e in world.enemies.duplicate():
		if e.dead:
			continue
		var offset: Vector2 = e.global_position - global_position
		if offset.length() < FLARE_RADIUS:
			e.take_damage(damage, offset.normalized())
			e.push(offset.normalized() * FLARE_PUSH)
	world.clear_enemy_bullets(center, FLARE_BULLET_RADIUS)
	_iframes = maxf(_iframes, 0.35)


# ------------------------------------------------------------------ getting hurt
func hurt(amount: float, source: String, from_pos: Vector2) -> void:
	if not can_be_hit():
		return
	if Run.stats.shade and shade_ready:
		_break_shade()
		return
	var revive_was_used := Run.revive_used
	var fatal := Run.take_damage(int(ceil(amount)), source)
	_iframes = HURT_IFRAMES
	_blink = HURT_IFRAMES
	_flash = 1.0
	_knock = (global_position - from_pos).normalized() * HURT_KNOCKBACK
	Sound.play("player_hurt")
	Juice.shake(0.55)
	Juice.hitstop(0.09)
	Fx.burst(world.fx, global_position + Vector2(0, -8), UiTheme.RED, 10, 80, 0.4, 2.0)
	damaged.emit()
	if fatal:
		_die()
		return
	if Run.revive_used and not revive_was_used:
		Fx.text(world.fx, global_position, "续芯复燃！", UiTheme.GOLD)
		Fx.ring(world.fx, global_position, 60, UiTheme.AMBER, 0.5, 3)
		Sound.play("relic")
		_iframes = REVIVE_IFRAMES
		_blink = REVIVE_IFRAMES
	if Run.stats.bell:
		release_flare(true)


func _break_shade() -> void:
	shade_ready = false
	_iframes = SHADE_IFRAMES
	_blink = SHADE_IFRAMES
	Sound.play("shield_break")
	Fx.ring(world.fx, global_position + Vector2(0, -6), 26, UiTheme.TEAL, 0.35, 2)
	Fx.text(world.fx, global_position, "灯罩碎了", UiTheme.TEAL)


func _die() -> void:
	dead = true
	sprite.play("hurt")
	lantern.visible = false
	Sound.play("player_die")
	Juice.shake(0.8)
	Fx.burst(world.fx, global_position + Vector2(0, -8), UiTheme.AMBER, 30, 120, 0.9, 2.0)
	# the light gutters out, the body fades, then whoever is listening ends the run
	var tw := create_tween()
	tw.tween_property(lantern_light, "energy", 0.0, 1.2)
	tw.parallel().tween_property(sprite, "modulate", Color(0.3, 0.3, 0.4, 0.0), 1.2).set_delay(0.3)
	tw.tween_interval(DEATH_TIME - 1.5)
	tw.tween_callback(died.emit)


# ------------------------------------------------------------------ looks
func _animate(delta: float) -> void:
	var moving := velocity.length() > 12.0
	var wanted := "dash" if _dash_t > 0.0 else ("run" if moving else "idle")
	if sprite.animation != wanted:
		sprite.play(wanted)
	sprite.visible = not (_blink > 0.0 and int(_blink * 18.0) % 2 == 0)
	# the lantern is held out towards the aim point, and drawn behind the body when aiming up
	var hold := aim * 8.0 + AIM_ORIGIN
	hold.x = clampf(hold.x, -9, 9)
	lantern.position = hold.round()
	lantern.z_index = -1 if aim.y < -0.5 else 1
	lantern_light.position = hold
	var health := float(Run.hp) / float(maxi(1, Run.max_hp))
	lantern_light.base_scale = LIGHT_RADIUS / Lights.TEXTURE_RADIUS * lerpf(LIGHT_AT_ZERO_HP, 1.0, health) * light_mult
	if moving and _dash_t <= 0.0:
		_step_cd -= delta
		if _step_cd <= 0.0:
			_step_cd = FOOTSTEP_INTERVAL
			Sound.play("footstep", -14.0, 1.0, 0.15)
			if randf() < 0.4:
				Fx.dust(world.fx, global_position + Vector2(randf_range(-3, 3), -1))


# ------------------------------------------------------------------ orbiting motes
func _sync_motes() -> void:
	if not is_inside_tree():
		return
	var want := Run.stats.motes
	while _motes.size() < want:
		var mote := SpriteLib.make_sprite("bolt")
		mote.material = Fx.unshaded()
		mote.scale = Vector2(0.8, 0.8)
		mote.add_child(Lights.make(Color(1, 0.7, 0.4), 24.0, 0.6))
		add_child(mote)
		_motes.append(mote)
	while _motes.size() > want:
		_motes.pop_back().queue_free()


func _update_motes(delta: float) -> void:
	if _motes.is_empty():
		return
	_mote_angle += delta * 3.4
	for i in _motes.size():
		var angle := _mote_angle + i * TAU / _motes.size()
		_motes[i].position = Vector2(cos(angle), sin(angle) * 0.8) * MOTE_ORBIT + AIM_ORIGIN
		if combat:
			_burn_with_mote(global_position + _motes[i].position)


func _burn_with_mote(mote_pos: Vector2) -> void:
	for e in world.enemies:
		if e.dead or e.spawning():
			continue
		if e.center().distance_to(mote_pos) >= 6.0 + e.hit_radius:
			continue
		var id := e.get_instance_id()
		if _clock >= _mote_ready_at.get(id, 0.0):
			_mote_ready_at[id] = _clock + MOTE_HIT_INTERVAL
			e.take_damage(MOTE_DAMAGE, (e.global_position - global_position).normalized())
