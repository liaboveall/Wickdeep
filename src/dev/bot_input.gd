class_name BotInput
extends PlayerInput
## Automated player used by `--autoplay` play-throughs: fights, dodges bullets, explores rooms,
## takes relics and stairs. It exists to prove a whole run works end to end (and to tune balance).
## It only uses what a player could see: positions, bullets, telegraph markers, wind-ups.

const ENGAGE_RANGE := 160.0          # outside a locked room, enemies closer than this are fought
const SIGHT_RANGE := 320.0
const KEEP_DISTANCE := 85.0
const KEEP_DISTANCE_BOSS := 110.0
const DODGE_LOOKAHEAD := 0.45        # seconds of bullet flight considered
const DODGE_CLEARANCE := 11.0
const DASH_URGENCY := 0.16           # dash if the hit is this close in time
const INTERACT_REACH := 14.0
const STUCK_CHECK := 1.4

var _path := PackedVector2Array()
var _path_t := 0.0
var _goal := Vector2.INF
var _strafe := 1.0
var _strafe_t := 0.0
var _stuck_t := 0.0
var _last_pos := Vector2.ZERO
var _unstick := 0.0
var _unstick_dir := Vector2.ZERO
var _interact_cd := 0.0
var _camp_t := 0.0
var _shopped := false


func update(p: Player, delta: float) -> void:
	var w := p.world
	clear()
	_interact_cd -= delta
	if _wriggle_free(p, delta):
		return
	var pos := p.global_position
	var enemy := w.nearest_enemy(pos, SIGHT_RANGE)
	var level := w as Level
	var locked_in := level != null and level.director.in_fight()
	if enemy and (locked_in or pos.distance_to(enemy.global_position) < ENGAGE_RANGE):
		_fight(p, w, enemy, delta)
	elif level:
		_explore_level(p, level, delta)
	elif w is Camp:
		_visit_camp(p, w, delta)
	_dodge(p, w)


## If the bot has not moved for a while, walk in a random direction for a moment.
func _wriggle_free(p: Player, delta: float) -> bool:
	var pos := p.global_position
	_stuck_t += delta
	if _stuck_t > STUCK_CHECK:
		if pos.distance_to(_last_pos) < 5.0 and _goal != Vector2.INF:
			_unstick = 0.45
			_unstick_dir = Vector2.from_angle(randf() * TAU)
			_path = PackedVector2Array()
		_stuck_t = 0.0
		_last_pos = pos
	if _unstick <= 0.0:
		return false
	_unstick -= delta
	move = _unstick_dir
	return true


# ------------------------------------------------------------------ combat
func _fight(p: Player, w: World, e: Enemy, delta: float) -> void:
	var pos := p.global_position
	var target := e.center()
	aim = (target - (pos + Player.AIM_ORIGIN)).normalized()
	aim_point = target
	var clear_shot := w.grid.line_of_sight(pos + Player.AIM_ORIGIN, target)
	shoot = clear_shot
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.0, 2.5)
		_strafe = -_strafe
	# circle the enemy at a comfortable distance
	var dist := pos.distance_to(e.global_position)
	var radial := (pos - e.global_position).normalized()
	var tangent := radial.orthogonal() * _strafe
	var keep := KEEP_DISTANCE_BOSS if e.is_boss() else KEEP_DISTANCE
	if not clear_shot:
		_follow(p, w, e.global_position, delta)
	elif dist < keep - 25.0:
		move = (radial + tangent * 0.6).normalized()
	elif dist > keep + 40.0:
		move = (-radial * 0.8 + tangent * 0.4).normalized()
	else:
		move = tangent
	if p.get_slide_collision_count() > 0:
		_strafe = -_strafe
	if Run.flare_ready() and (e.is_boss() or _enemies_within(w, pos, 80.0) >= 2):
		flare = true


func _enemies_within(w: World, pos: Vector2, radius: float) -> int:
	var n := 0
	for e in w.enemies:
		if not e.dead and e.global_position.distance_to(pos) < radius:
			n += 1
	return n


## Step (or dash) out of the way of whatever is about to hit: bullets on a collision course,
## enemies in arm's reach, telegraphed ground marks, and melee wind-ups.
func _dodge(p: Player, w: World) -> void:
	var body := p.global_position + Player.HIT_CENTER
	var soonest := 99.0
	var away := Vector2.ZERO
	for b in w.enemy_bullets():
		var rel := b.position - body
		if rel.length() > 80.0 or b.vel.length_squared() < 1.0:
			continue
		var t := -rel.dot(b.vel) / b.vel.length_squared()   # time of closest approach
		if t < 0.0 or t > DODGE_LOOKAHEAD:
			continue
		var closest := rel + b.vel * t
		if closest.length() < DODGE_CLEARANCE and t < soonest:
			soonest = t
			var sideways := b.vel.orthogonal().normalized()
			away = -sideways if closest.dot(sideways) > 0.0 else sideways
	for e in w.enemies:
		if e.dead:
			continue
		if e.global_position.distance_to(p.global_position) < 18.0 and soonest > 0.2:
			soonest = 0.2
			away = (p.global_position - e.global_position).normalized()
	for node in p.get_tree().get_nodes_in_group(Fx.TELEGRAPH_GROUP):
		var mark := node as Fx.Telegraph
		var offset := p.global_position - mark.position
		if offset.length() < mark.radius + 12.0:
			away = offset.normalized() if offset.length() > 0.5 else Vector2.RIGHT
			soonest = minf(soonest, 0.3)
	for e in w.enemies:
		var offset := p.global_position - e.global_position
		if not e.dead and offset.length() < e.danger_radius():
			away = (offset.normalized() + offset.normalized().orthogonal() * 0.6).normalized()
	if away != Vector2.ZERO:
		move = (away * 1.4 + move * 0.3).normalized()
		if soonest < DASH_URGENCY:
			dash = true


# ------------------------------------------------------------------ exploring
## Clear the nearest unfinished room; then altar and shrine; then the stairs.
func _explore_level(p: Player, level: Level, delta: float) -> void:
	var goal := _next_room(p, level)
	if goal != Vector2.INF:
		_walk_to(p, level, goal, delta)
		return
	var target := _find(level, Interactable.Kind.ALTAR)
	if target == null and Run.is_hurt():
		target = _find(level, Interactable.Kind.SHRINE)
	if target == null:
		target = _find(level, Interactable.Kind.STAIRS)
	if target:
		_use(p, level, target, delta)


## Centre of the nearest room that still has a fight in it, or INF. The boss room is left for
## last, and until a waiting shrine has been used.
func _next_room(p: Player, level: Level) -> Vector2:
	var others_left := false
	for room in level.gen.rooms:
		if not level.director.is_cleared(room.id) and room.type != DungeonRoom.Type.BOSS:
			others_left = true
	var shrine_waiting := Run.is_hurt() and _find(level, Interactable.Kind.SHRINE) != null
	var best := Vector2.INF
	var best_dist := INF
	for room in level.gen.rooms:
		if level.director.is_cleared(room.id):
			continue
		if room.type == DungeonRoom.Type.BOSS and (others_left or shrine_waiting):
			continue
		var spot := _standing_spot(level, room)
		var dist := spot.distance_to(p.global_position)
		if dist < best_dist:
			best_dist = dist
			best = spot
	return best


## The room's centre, or the open cell nearest to it when a pillar stands in the middle.
func _standing_spot(level: Level, room: DungeonRoom) -> Vector2:
	var spot := NavGrid.cell_center(room.center)
	if not level.grid.is_solid_at(spot):
		return spot
	var nearest := INF
	for c in level.gen.open_cells(room, 2):
		var d := Vector2(c).distance_to(Vector2(room.center))
		if d < nearest:
			nearest = d
			spot = NavGrid.cell_center(c)
	return spot


## In the camp: wait a moment, visit Granny once, then take the stairs.
func _visit_camp(p: Player, camp: Camp, delta: float) -> void:
	_camp_t += delta
	if _camp_t < 1.5:
		return
	var stall := _find(camp, Interactable.Kind.SHOP)
	if stall and not _shopped:
		# the stall is solid, so "close enough" is a little further than for other things
		if p.global_position.distance_to(stall.global_position) < 20.0:
			_shopped = true
			interact = true
		else:
			_walk_to(p, camp, stall.global_position, delta)
		return
	var stairs := _find(camp, Interactable.Kind.STAIRS)
	if stairs:
		_use(p, camp, stairs, delta)


func _find(w: World, kind: Interactable.Kind) -> Interactable:
	for it in w.interactables:
		if is_instance_valid(it) and it.enabled and it.kind == kind:
			return it
	return null


func _use(p: Player, w: World, target: Interactable, delta: float) -> void:
	if p.global_position.distance_to(target.global_position) < INTERACT_REACH and _interact_cd <= 0.0:
		interact = true
		_interact_cd = 1.0
		return
	_walk_to(p, w, target.global_position, delta)


func _walk_to(p: Player, w: World, goal: Vector2, delta: float) -> void:
	_follow(p, w, goal, delta)
	if move.length() > 0.1:
		aim = move


## Head for `goal` along a path that is refreshed now and then.
func _follow(p: Player, w: World, goal: Vector2, delta: float) -> void:
	_path_t -= delta
	if goal.distance_to(_goal) > 8.0 or _path.is_empty() or _path_t <= 0.0:
		_goal = goal
		_path_t = 0.7
		_path = w.grid.path(p.global_position, goal)
	while _path.size() > 1 and p.global_position.distance_to(_path[0]) < 6.0:
		_path.remove_at(0)
	var waypoint := _path[0] if _path.size() > 0 else goal
	move = (waypoint - p.global_position).normalized()
