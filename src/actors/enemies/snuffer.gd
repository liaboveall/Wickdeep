extends Boss
## Final boss: the Snuffer. Three phases of bullet patterns; dims the player's light and summons
## shadelings; rains telegraphed wax in the last phase.
##
## Between attacks it drifts around the upper half of the arena (IDLE). Each phase has a rotation
## of attacks that is shuffled, played through and reshuffled.

enum { INTRO, IDLE, RING, AIMED, SNUFF, SPIRAL, CHARGE_TELL, CHARGE, SUMMON, RAIN, FAN }

const ROTATIONS := {
	1: [RING, AIMED, RING, SNUFF, AIMED],
	2: [SPIRAL, CHARGE_TELL, RING, SUMMON, AIMED, CHARGE_TELL],
	3: [RAIN, SPIRAL, FAN, CHARGE_TELL, RAIN, SNUFF, SPIRAL],
}
## Seconds before an attack fires (for SPIRAL: how long it keeps spinning).
const WINDUP := {
	RING: 0.5, AIMED: 0.45, SNUFF: 0.8, SPIRAL: 3.0, CHARGE_TELL: 0.85, SUMMON: 0.7, RAIN: 0.6, FAN: 0.5,
}
## Later phases rest less between attacks.
const REST_SCALE := [1.0, 0.8, 0.6]

const INTRO_TIME := 1.6
const CHARGE_SPEED := 320.0
const CHARGE_TIME := 1.0
const CHARGE_AIM_LOCK := 0.2
const CHARGE_DAMAGE := 2
const SNUFF_DURATION := 4.5
const RAIN_DROPS := 8
const RAIN_DELAY := 0.95
const RAIN_HIT_RADIUS := 14.0
const AIM_LINE_FROM := Vector2(0, -12)

var _rotation: Array = []
var _volleys := 0
var _goal := Vector2.ZERO
var _goal_t := 0.0
var _spiral_angle := 0.0
var _spiral_cd := 0.0
var _charge := Vector2.ZERO
var _rain: Array = []           # [position, seconds until the drop lands]
var _line: Line2D
var _light: PointLight2D


func _configure() -> void:
	sheet = "snuffer"
	max_hp = 2400.0
	speed = 40.0
	accel = 260.0
	hit_radius = 15.0
	hit_offset = Vector2(0, -22)
	sprite_offset = Vector2(0, -24)
	shadow_width = 30
	flying = true
	embers = Vector2i(0, 0)
	enter(INTRO, INTRO_TIME)


func _build() -> void:
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = Color(1, 0.25, 0.3, 0.0)
	_line.material = Fx.unshaded()
	add_child(_line)
	_light = Lights.make(Color(0.75, 0.5, 1.0), 105.0, 1.0)
	_light.position = Vector2(0, -22)
	add_child(_light)


func _ai(delta: float) -> void:
	hover(2.5, 2.0)
	_tick_rain(delta)
	match state:
		INTRO:
			desired = Vector2.ZERO
			if state_t <= 0.0:
				enter(IDLE, 0.5)
		IDLE:
			play("idle")
			_drift(delta)
			if state_t <= 0.0:
				_begin(_next_attack())
		SPIRAL:
			_hold("cast")
			_spin_spiral(delta)
			if state_t <= 0.0:
				_rest(1.0)
		CHARGE_TELL:
			_hold("charge")
			_aim_charge()
			if state_t <= 0.0:
				_start_charge()
		CHARGE:
			_charge_forward()
		_:
			# every other attack stands still, then fires when its timer runs out
			_hold("cast")
			if state_t <= 0.0:
				_fire(state)


func _hold(anim: String) -> void:
	play(anim)
	desired = Vector2.ZERO


# ------------------------------------------------------------------ attack selection
func _next_attack() -> int:
	if _rotation.is_empty():
		_rotation = ROTATIONS[phase].duplicate()
		_rotation.shuffle()
	return _rotation.pop_front()


func _begin(attack: int) -> void:
	enter(attack, WINDUP[attack])
	match attack:
		RING:
			_volleys = 3 if phase == 1 else 4
		AIMED, FAN:
			_volleys = 3
		SPIRAL:
			_spiral_cd = 0.4


func _fire(attack: int) -> void:
	match attack:
		RING:
			_ring_volley()
		AIMED:
			_aimed_volley()
		FAN:
			_fan_volley()
		SNUFF:
			_snuff()
		SUMMON:
			_summon_wisps()
		RAIN:
			_call_rain()


## Go back to drifting for a while (shorter in later phases).
func _rest(seconds: float) -> void:
	enter(IDLE, seconds * REST_SCALE[phase - 1])


## One volley of a multi-volley attack is out: queue the next, or rest when they are all done.
func _volley_done(interval: float, rest: float) -> void:
	_volleys -= 1
	if _volleys > 0:
		state_t = interval
	else:
		_rest(rest)


func _drift(delta: float) -> void:
	_goal_t -= delta
	if _goal_t <= 0.0:
		var room := arena()
		_goal_t = randf_range(1.2, 2.2)
		_goal = Vector2(randf_range(room.position.x + 40, room.end.x - 40),
			randf_range(room.position.y + 36, room.position.y + room.size.y * 0.55))
	desired = (_goal - global_position).limit_length(speed)


# ------------------------------------------------------------------ attacks
## A dense ring with lanes left open to slip through.
func _ring_volley() -> void:
	ring_shot("orb_violet", 28, 82.0 + phase * 8.0, randf() * TAU, 7, 2)
	Sound.play("enemy_shoot", -1.0, 0.6)
	_volley_done(0.55, 0.9)


func _aimed_volley() -> void:
	if phase == 1:
		fan_shot("orb_red", aim_at_player(), 3, 0.18, 145.0)
	else:
		fan_shot("orb_red", aim_at_player(), 7, 0.16, 145.0)
	Sound.play("enemy_shoot", -2.0, 1.1)
	_volley_done(0.28, 0.8)


func _fan_volley() -> void:
	fan_shot("orb_red", to_player().normalized(), 9, 0.17, 120.0)
	Sound.play("enemy_shoot", -2.0, 0.9)
	_volley_done(0.45, 0.7)


## Dim the player's lantern and send shadelings in under cover of the dark.
func _snuff() -> void:
	(world as Level).snuff_light(SNUFF_DURATION)
	Sound.play("boss_roar", -4.0, 1.3)
	var room := arena()
	for k in 3 + phase:
		var pos := Vector2(randf_range(room.position.x + 20, room.end.x - 20),
			randf_range(room.position.y + 20, room.end.y - 20))
		if pos.distance_to(player().global_position) < 70.0:
			pos = room.get_center()
		summon("shade", pos, 5)
	_rest(1.2)


func _summon_wisps() -> void:
	var room := arena()
	for k in 2:
		summon("wisp", Vector2(room.position.x + 40 + k * (room.size.x - 80), room.position.y + 40), 4)
	_rest(1.0)


func _spin_spiral(delta: float) -> void:
	_spiral_cd -= delta
	if _spiral_cd > 0.0:
		return
	var frenzied := phase == 3
	_spiral_cd = 0.08 if frenzied else 0.1
	_spiral_angle += 0.24
	var arms := 4 if frenzied else 3
	for k in arms:
		shoot("orb_violet", Vector2.from_angle(_spiral_angle + k * TAU / arms), 88.0)
	if frenzied:
		shoot("orb_red", Vector2.from_angle(-_spiral_angle * 0.8), 70.0)   # a slow counter-spiral


func _aim_charge() -> void:
	if state_t > CHARGE_AIM_LOCK:
		_charge = to_player().normalized()
	_line.default_color = Color(1, 0.3, 0.35, 0.3 + 0.5 * absf(sin(state_t * 20.0)))
	_line.points = PackedVector2Array([AIM_LINE_FROM, AIM_LINE_FROM + _charge * 300.0])


func _start_charge() -> void:
	_line.points = PackedVector2Array()
	contact_damage = CHARGE_DAMAGE
	Sound.play("knight_charge", 0.0, 0.7)
	enter(CHARGE, CHARGE_TIME)


func _charge_forward() -> void:
	play("charge")
	lunge(_charge * CHARGE_SPEED)
	if int(state_t * 40) % 3 == 0:
		Fx.burst(world.fx, global_position + Vector2(0, -10), Color("#6e3f8a"), 3, 40, 0.4, 2.0)
	if hit_wall() or state_t <= 0.0:
		contact_damage = 1
		Juice.shake(0.5)
		Sound.play("boss_slam")
		ring_shot("orb_violet", 16, 90.0, randf() * TAU)
		_rest(1.0)


## Mark the player's spot and a scatter around it; wax lands on each mark a moment later.
func _call_rain() -> void:
	var around := player().global_position
	var spots: Array[Vector2] = [around]
	for k in RAIN_DROPS:
		spots.append(around + Vector2.from_angle(randf() * TAU) * randf_range(26, 85))
	for spot in spots:
		if world.grid.is_solid_at(spot):
			continue
		world.telegraph(spot, 13.0, RAIN_DELAY, Color(0.95, 0.85, 0.6))
		_rain.append([spot, RAIN_DELAY])
	Sound.play("spawn", -2.0, 0.8)
	_rest(1.4)


func _tick_rain(delta: float) -> void:
	for drop: Array in _rain.duplicate():
		drop[1] -= delta
		if drop[1] <= 0.0:
			_rain.erase(drop)
			_land_wax(drop[0])


func _land_wax(pos: Vector2) -> void:
	var wax := SpriteLib.make_sprite("wax")
	wax.material = Fx.unshaded()
	wax.position = pos + Vector2(0, -70)
	world.fx.add_child(wax)
	var tw := wax.create_tween()
	tw.tween_property(wax, "position", pos, 0.12)
	tw.tween_callback(wax.queue_free)
	Fx.anim(world.fx, "boom", pos, "pop", Fx.Z_ANIM + 1, 0.55)
	Sound.play("explode", -10.0, 1.4)
	var p := player()
	if p.can_be_hit() and p.global_position.distance_to(pos) < RAIN_HIT_RADIUS:
		p.hurt(1, kind, pos)


# ------------------------------------------------------------------ phases
func _on_phase(new_phase: int) -> void:
	stagger(1.6, 600.0)
	_rotation.clear()
	_line.points = PackedVector2Array()
	contact_damage = 1
	Juice.shake(0.8)
	Fx.ring(world.fx, center(), 140, Color("#dba8ec"), 0.6, 3)
	Fx.light_flash(world.fx, center(), Color(0.8, 0.5, 1.0), 2.5, 2.5, 0.8)
	world.hud.toast("熄灯者愈发狂暴了……" if new_phase == 3 else "熄灯者张开了双臂！", UiTheme.RED)
	_light.energy = 0.8 + 0.4 * (new_phase - 1)
	enter(IDLE, 1.4)
