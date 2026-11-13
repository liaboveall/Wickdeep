class_name Enemy
extends CharacterBody2D
## Base for every enemy and boss.
##
## A subclass sets its numbers in _configure(), adds any extra nodes in _build(), and thinks in
## _ai(delta), usually as a small state machine: enter(state, seconds) switches state and starts
## its timer, state_t counts down while the enemy is free to act (not stunned, player alive).

signal died(enemy: Enemy)

const SPAWN_FADE := 0.3
const KNOCKBACK := 55.0
const KNOCKBACK_DECAY := 650.0
const STUN_DAMAGE_MULT := 1.5
const CONTACT_INTERVAL := 0.5         # seconds between touch hits on the player
const BURN_TIME := 2.0
const BURN_TICK := 0.4
const BURN_DAMAGE := 4.0
const EXPLOSION_RADIUS := 34.0        # the "combustion" relic's blast
const PATH_REFRESH := 0.45
const SEPARATION := 10.0

var world: World
var kind := "slime"
var depth_level := 1

# ---- tuning (set in _configure)
var sheet := "slime"
var max_hp := 20.0
var speed := 40.0
var accel := 500.0
var contact_damage := 1
var hit_radius := 6.0
var hit_offset := Vector2(0, -6)      # body centre relative to the feet
var sprite_offset := Vector2(0, -8)
var shadow_width := 12
var body_radius := 4.5
var knock_resist := 1.0               # multiplier on knockback taken (0 = immovable)
var embers := Vector2i(1, 3)          # min / max dropped on death
var flying := false                   # flyers do not push each other apart
var face_player := true
var scales_with_depth := true
var spawn_delay := 0.45               # can neither act nor be hit while materialising

# ---- runtime
var hp := 20.0
var dead := false
var stun_t := 0.0
var desired := Vector2.ZERO           # velocity the AI wants; the body accelerates towards it
var state := 0
var state_t := 0.0
var age := 0.0
var sprite: AnimatedSprite2D

var _flash_mat: ShaderMaterial
var _flash := 0.0
var _knock := Vector2.ZERO
var _spawn_t := 0.0
var _contact_cd := 0.0
var _burn_t := 0.0
var _burn_tick := 0.0
var _burn_fx := 0.0
var _path := PackedVector2Array()
var _path_t := 0.0


func _ready() -> void:
	_configure()
	if scales_with_depth:
		max_hp *= Bestiary.hp_scale(depth_level)
	hp = max_hp
	_spawn_t = spawn_delay
	ActorGfx.setup_body(self, PhysicsLayers.ENEMY, body_radius)
	add_child(ActorGfx.shadow(shadow_width))
	sprite = SpriteLib.make_sprite(sheet)
	sprite.position = sprite_offset
	_flash_mat = ActorGfx.flash_material()
	sprite.material = _flash_mat
	add_child(sprite)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, SPAWN_FADE)
	_build()


# ------------------------------------------------------------------ for subclasses to override
## Set the tuning variables and the starting state.
func _configure() -> void:
	pass


## Add extra child nodes (lights, aim lines). The sprite exists by now.
func _build() -> void:
	pass


## Decide what to do this frame: set `desired` (or `velocity` for instant moves) and act.
func _ai(_delta: float) -> void:
	pass


func _on_damaged(_amount: float) -> void:
	pass


func _on_stun_end() -> void:
	pass


func _on_death() -> void:
	pass


## While this is above zero the enemy is winding up a melee move that reaches about that far.
## The test bot uses it to step away, the way a player reads the animation.
func danger_radius() -> float:
	return 0.0


# ------------------------------------------------------------------ helpers
func enter(new_state: int, duration := 0.0) -> void:
	state = new_state
	state_t = duration


func spawning() -> bool:
	return _spawn_t > 0.0


func player() -> Player:
	return world.player


## Body centre in world space: where bullets hit and where shots leave from.
func center() -> Vector2:
	return global_position + hit_offset


func to_player() -> Vector2:
	return world.player.global_position - global_position if world.player else Vector2.ZERO


## Unit vector from this enemy's centre to the middle of the player's body.
func aim_at_player() -> Vector2:
	return (world.player.global_position + Player.HIT_CENTER - center()).normalized()


func sees_player(from_center := false) -> bool:
	return world.grid.line_of_sight(center() if from_center else global_position, world.player.global_position)


func play(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


## Flyers bob up and down a little.
func hover(rate: float, amount: float) -> void:
	sprite.position.y = sprite_offset.y + sin(age * rate) * amount


## Blink white while winding up an attack.
func flicker(blinks_per_second: float, strength: float) -> void:
	_flash = strength if int(state_t * blinks_per_second) % 2 == 0 else 0.0


func brake(rate: float, delta: float) -> void:
	desired = desired.move_toward(Vector2.ZERO, rate * delta)


## Move at full speed right now, skipping acceleration (leaps, charges).
func lunge(v: Vector2) -> void:
	desired = v
	velocity = v


func hit_wall() -> bool:
	return get_slide_collision_count() > 0


## Move towards a point: straight if there is line of sight, otherwise along an A* path.
func steer_to(target: Vector2, spd: float, delta: float) -> void:
	if world.grid.line_of_sight(global_position, target):
		desired = (target - global_position).normalized() * spd
		_path = PackedVector2Array()
		return
	_path_t -= delta
	if _path_t <= 0.0 or _path.is_empty():
		_path_t = PATH_REFRESH
		_path = world.grid.path(global_position, target)
	while _path.size() > 1 and global_position.distance_to(_path[0]) < 7.0:
		_path.remove_at(0)
	var waypoint := _path[0] if _path.size() > 0 else target
	desired = (waypoint - global_position).normalized() * spd


func push(v: Vector2) -> void:
	_knock += v * knock_resist


func stun(seconds: float) -> void:
	stun_t = seconds


# ------------------------------------------------------------------ shooting
## Fire a bullet from this enemy's body.
func shoot(sheet_name: String, dir: Vector2, spd: float, dmg := 1, radius := 3.0) -> Projectile:
	return world.enemy_shot(sheet_name, center(), dir, spd, kind, dmg, radius)


## `count` bullets spread evenly around `dir`, `step` radians apart.
func fan_shot(sheet_name: String, dir: Vector2, count: int, step: float, spd: float, radius := 3.0) -> void:
	for i in count:
		shoot(sheet_name, dir.rotated((i - (count - 1) / 2.0) * step), spd, 1, radius)


## `count` bullets in a full circle. With gap_period > 0, the first `gap_width` of every
## `gap_period` bullets are left out, which leaves lanes to dodge through.
func ring_shot(sheet_name: String, count: int, spd: float, offset_angle := 0.0, gap_period := 0,
		gap_width := 1) -> void:
	for i in count:
		if gap_period > 0 and i % gap_period < gap_width:
			continue
		shoot(sheet_name, Vector2.from_angle(offset_angle + i * TAU / count), spd)


# ------------------------------------------------------------------ frame
func _physics_process(delta: float) -> void:
	if dead:
		return
	if _spawn_t > 0.0:
		_spawn_t -= delta
		return
	age += delta
	_flash = maxf(0.0, _flash - delta * 7.0)
	_contact_cd -= delta
	_tick_burn(delta)
	if dead:
		return
	var p := world.player
	if stun_t > 0.0:
		stun_t -= delta
		desired = Vector2.ZERO
		if stun_t <= 0.0:
			_on_stun_end()
	elif p and not p.dead:
		state_t -= delta
		_ai(delta)
	else:
		brake(200.0, delta)
	_flash_mat.set_shader_parameter("flash", _flash)
	_separate()
	velocity = velocity.move_toward(desired, accel * delta) + _knock
	_knock = _knock.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	move_and_slide()
	velocity -= _knock
	if face_player and p:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 2.0:
			sprite.flip_h = dx < 0.0
	_touch_player(p)


func _tick_burn(delta: float) -> void:
	if _burn_t <= 0.0:
		return
	_burn_t -= delta
	_burn_tick -= delta
	_burn_fx -= delta
	if _burn_fx <= 0.0:
		_burn_fx = 0.12
		Fx.burst(world.fx, center() + Vector2(randf_range(-4, 4), 0), UiTheme.EMBER, 2, 25, 0.35, 1.0, true, -40.0)
	if _burn_tick <= 0.0:
		_burn_tick = BURN_TICK
		take_damage(BURN_DAMAGE, Vector2.ZERO, false, true)


## Ground enemies nudge each other apart so they do not stack on one spot.
func _separate() -> void:
	if flying:
		return
	for other in world.enemies:
		if other == self or other.dead:
			continue
		var away := global_position - other.global_position
		var dist := away.length()
		var min_dist := SEPARATION + (8.0 if is_boss() or other.is_boss() else 0.0)
		if dist < min_dist and dist > 0.01:
			desired += away / dist * (min_dist - dist) * 8.0


func _touch_player(p: Player) -> void:
	if contact_damage <= 0 or p == null or _contact_cd > 0.0 or not p.can_be_hit():
		return
	if p.global_position.distance_to(global_position) < hit_radius + Player.HIT_RADIUS + 2.0:
		_contact_cd = CONTACT_INTERVAL
		p.hurt(contact_damage, kind, global_position)


func is_boss() -> bool:
	return false


# ------------------------------------------------------------------ damage and death
## `dir` knocks the enemy back; `burn` marks damage over time (quiet, orange numbers).
func take_damage(amount: float, dir := Vector2.ZERO, crit := false, burn := false) -> void:
	if dead or _spawn_t > 0.0:
		return
	if stun_t > 0.0:
		amount *= STUN_DAMAGE_MULT
	hp -= amount
	Run.register_damage_dealt(amount)
	_flash = 1.0
	if dir != Vector2.ZERO:
		_knock += dir * KNOCKBACK * knock_resist
	var color := UiTheme.GOLD if crit else (UiTheme.EMBER if burn else UiTheme.CREAM)
	Fx.number(world.fx, center(), amount, color, crit)
	if not burn:
		Sound.play("crit" if crit else "hit", -4.0, 1.0, 0.12)
	_on_damaged(amount)
	if hp <= 0.0:
		die()


func ignite() -> void:
	if _burn_t <= 0.0:
		Sound.play("burn", -6.0)
	_burn_t = BURN_TIME


func die() -> void:
	if dead:
		return
	dead = true
	Run.register_kill(kind)
	Fx.anim(world.fx, "puff", center(), "pop", Fx.Z_ANIM, 1.4 if is_boss() else 1.0, false)
	Fx.burst(world.fx, center(), UiTheme.AMBER, 8, 90, 0.4, 2.0)
	Sound.play("enemy_die", -2.0, 1.0, 0.1)
	if not is_boss():
		Juice.hitstop(0.035)
		Juice.shake(0.12)
	world.drop_embers(global_position, randi_range(embers.x, embers.y))
	if Run.stats.explode_on_kill > 0.0:
		_explode(Run.stats.explode_on_kill)
	died.emit(self)
	_on_death()
	queue_free()


func _explode(damage: float) -> void:
	Fx.anim(world.fx, "boom", center(), "pop", Fx.Z_ANIM + 1, 0.8)
	Sound.play("explode", -6.0)
	for other in world.enemies.duplicate():
		if other != self and not other.dead and other.global_position.distance_to(global_position) < EXPLOSION_RADIUS:
			other.take_damage(damage, (other.global_position - global_position).normalized())
