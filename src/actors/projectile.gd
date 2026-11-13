class_name Projectile
extends Node2D
## Bullets for both teams. Moved manually in small steps against the tile grid (exact wall hits and
## ricochets) and tested against actors by distance, which keeps hundreds of bullets cheap.

enum Team { PLAYER, ENEMY }

const STEP := 4.0                 # pixels per collision sub-step
const HOMING_RANGE := 110.0
const ENEMY_RANGE := 900.0
const CRIT_MULT := 2.0
const SHARD_COUNT := 3
const MAX_LIT_BOLTS := 12         # dynamic lights are not free; cap how many bolts glow at once

static var _lit_bolts := 0

var world: World
var team := Team.PLAYER
var sheet := "bolt"
var vel := Vector2.ZERO
var damage := 10.0
var radius := 3.0
var pierce := 0
var bounces := 0
var homing := 0.0
var range_left := 220.0
var crit := false
var burn_chance := 0.0
var shatter := false
var is_shard := false
var source := ""                  # enemy kind that fired it, for the damage statistics
var dead := false
var visual_scale := 1.0
var spin := 0.0                   # radians per second the flight path curves
var max_age := 8.0

var _age := 0.0
var _hit := {}                    # enemies this bullet has already gone through
var _sprite: AnimatedSprite2D
var _light: PointLight2D


# ------------------------------------------------------------------ constructors
## One of the player's ember bolts, with everything the relics add to it.
static func bolt(stats: PlayerStats, origin: Vector2, angle: float) -> Projectile:
	var p := Projectile.new()
	p.position = origin
	p.vel = Vector2.from_angle(angle) * stats.shot_speed
	p.damage = stats.damage
	p.crit = randf() < stats.crit_chance
	p.pierce = stats.pierce
	p.bounces = stats.bounces
	p.homing = stats.homing
	p.range_left = stats.shot_range
	p.burn_chance = stats.burn_chance
	p.shatter = stats.shatter
	p.visual_scale = stats.bolt_scale
	p.radius = 3.0 * stats.bolt_scale
	return p


## An enemy bullet. `velocity` already includes any slow-down from relics.
static func hostile(sheet_name: String, origin: Vector2, velocity: Vector2, source_kind: String,
		damage_points := 1, hit_radius := 3.0) -> Projectile:
	var p := Projectile.new()
	p.team = Team.ENEMY
	p.sheet = sheet_name
	p.position = origin
	p.vel = velocity
	p.damage = damage_points
	p.radius = hit_radius
	p.source = source_kind
	p.range_left = ENEMY_RANGE
	return p


## A crystal splinter thrown off when a shattering bolt hits `from_enemy`.
func _make_shard(index: int, from_enemy: Enemy) -> Projectile:
	var p := Projectile.new()
	p.sheet = "shard"
	p.is_shard = true
	p.position = position
	p.vel = vel.rotated(randf_range(-1.2, 1.2) + (index - 1) * 0.9) * 0.7
	p.damage = damage * 0.4
	p.radius = 2.5
	p.range_left = 70.0
	p._hit = {from_enemy.get_instance_id(): true}
	return p


# ------------------------------------------------------------------ lifecycle
func _ready() -> void:
	_sprite = SpriteLib.make_sprite(sheet)
	_sprite.material = Fx.unshaded()
	_sprite.scale = Vector2(visual_scale, visual_scale)
	add_child(_sprite)
	_face_flight()
	if team == Team.PLAYER and not is_shard and _lit_bolts < MAX_LIT_BOLTS:
		_lit_bolts += 1
		_light = Lights.make(Color(1.0, 0.7, 0.4), 34.0 * visual_scale, 0.75)
		add_child(_light)


func _exit_tree() -> void:
	if _light:
		_lit_bolts -= 1
		_light = null


func _physics_process(delta: float) -> void:
	if dead:
		return
	_age += delta
	_steer(delta)
	var motion := vel * delta
	var steps := int(ceil(motion.length() / STEP))
	for i in steps:
		var step := motion / steps
		var next := position + step
		if world.grid.is_solid_at(next):
			if bounces > 0:
				bounces -= 1
				_bounce(step)
				continue
			die(true)
			return
		position = next
		if _check_hits():
			return
	range_left -= motion.length()
	_face_flight()
	if range_left <= 0.0 or _age > max_age:
		die(false)


func _steer(delta: float) -> void:
	if homing > 0.0 and team == Team.PLAYER:
		var target := world.nearest_enemy(position, HOMING_RANGE)
		if target:
			var wanted := (target.center() - position).normalized() * vel.length()
			vel = vel.lerp(wanted, clampf(homing * delta, 0.0, 1.0))
	if spin != 0.0:
		vel = vel.rotated(spin * delta)


## Arrows point where they fly; round bullets do not care.
func _face_flight() -> void:
	if sheet == "arrow":
		_sprite.rotation = vel.angle()


func _bounce(step: Vector2) -> void:
	var blocked_x := world.grid.is_solid_at(position + Vector2(step.x, 0))
	var blocked_y := world.grid.is_solid_at(position + Vector2(0, step.y))
	if blocked_x:
		vel.x = -vel.x
	if blocked_y:
		vel.y = -vel.y
	if not blocked_x and not blocked_y:
		vel = -vel
	_hit.clear()
	Fx.anim(world.fx, "spark", position, "pop", Fx.Z_ANIM, 0.7)


# ------------------------------------------------------------------ hits
## Returns true if the bullet was used up.
func _check_hits() -> bool:
	if team == Team.ENEMY:
		return _check_player()
	for e in world.enemies:
		if e.dead or e.spawning():
			continue
		var id := e.get_instance_id()
		if _hit.has(id):
			continue
		if e.center().distance_to(position) < radius + e.hit_radius:
			_hit[id] = true
			_hit_enemy(e)
			if pierce > 0:
				pierce -= 1
			else:
				die(true)
				return true
	for b in world.props:
		if is_instance_valid(b) and b.position.distance_to(position) < radius + b.radius:
			b.smash()
			die(true)
			return true
	return false


func _check_player() -> bool:
	var p := world.player
	if p and p.can_be_hit() and (p.global_position + Player.HIT_CENTER).distance_to(position) < radius + Player.HIT_RADIUS:
		p.hurt(damage, source, position)
		die(true)
		return true
	return false


func _hit_enemy(e: Enemy) -> void:
	e.take_damage(damage * (CRIT_MULT if crit else 1.0), vel.normalized(), crit)
	if burn_chance > 0.0 and randf() < burn_chance:
		e.ignite()
	if shatter and not is_shard:
		for k in SHARD_COUNT:
			world.add_projectile(_make_shard(k, e))


func die(impact: bool) -> void:
	if dead:
		return
	dead = true
	if impact:
		if team == Team.PLAYER:
			Fx.anim(world.fx, "spark", position, "pop", Fx.Z_ANIM, visual_scale)
		else:
			Fx.burst(world.fx, position, Color("#a466c4") if sheet == "orb_violet" else UiTheme.RED, 4, 40, 0.25, 1.5)
	queue_free()
