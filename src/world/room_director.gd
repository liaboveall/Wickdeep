class_name RoomDirector
extends Node
## Runs the rooms of a level: notices which room the player is in, bars the doors when a fight
## starts, sends in telegraphed waves and opens up again once everything is dead.
## The level listens to the signals to add sound, rewards and boss fights on top.

signal room_entered(room: DungeonRoom)
signal fight_started(room: DungeonRoom)
signal room_cleared(room: DungeonRoom)

const SPAWN_WARNING := 0.75           # seconds a spawn marker shows before the enemy appears
const SPAWN_MARKER_RADIUS := 9.0
const MIN_SPAWN_DISTANCE := 80.0      # from the player
const SPAWN_SPACING := 22.0           # between enemies of one wave
const SPAWN_COLOR := Color(0.95, 0.35, 0.3)
const SUMMON_COLOR := Color(0.65, 0.4, 0.95)


class RoomState:
	var visited := false
	var cleared := false
	var waves: Array = []      # enemy kinds per wave, decided when the fight starts
	var wave := 0


class PendingSpawn:
	var kind := ""
	var pos := Vector2.ZERO
	var depth_level := 1
	var time_left := 0.0


var level: Level
var states: Array[RoomState] = []
var current := -1          # id of the room the player is standing in
var active := -1           # id of the room with a fight in progress
var boss_fight := false    # boss fights end when the level says so, not when the room is empty
var _pending: Array[PendingSpawn] = []


func setup(owner_level: Level) -> void:
	level = owner_level
	for room in level.gen.rooms:
		var state := RoomState.new()
		state.cleared = not room.has_fight()
		states.append(state)


func in_fight() -> bool:
	return active >= 0


func is_cleared(room_id: int) -> bool:
	return states[room_id].cleared


func is_visited(room_id: int) -> bool:
	return states[room_id].visited


func _physics_process(delta: float) -> void:
	_tick_pending(delta)
	var player := level.player
	if player == null or player.dead:
		return
	var cell := NavGrid.cell_of(player.global_position)
	var room_id := level.gen.room_at_cell(cell)
	if room_id >= 0 and room_id != current:
		current = room_id
		states[room_id].visited = true
		room_entered.emit(level.gen.rooms[room_id])
	# a fight starts once the player is properly inside, not while still in the doorway
	if active < 0 and room_id >= 0 and not states[room_id].cleared:
		var room := level.gen.rooms[room_id]
		if room.rect.grow(-1).has_point(cell):
			_start_fight(room)
	if active >= 0 and not boss_fight and _pending.is_empty() and level.enemies.is_empty():
		_wave_finished()


# ------------------------------------------------------------------ fights
func _start_fight(room: DungeonRoom) -> void:
	active = room.id
	level.set_doors_barred(room.door_cells(), true)
	boss_fight = room.type == DungeonRoom.Type.BOSS
	if boss_fight:
		fight_started.emit(room)
		return
	var state := states[room.id]
	state.waves = Bestiary.compose(level.rng, level.depth, room.area())
	state.wave = 0
	fight_started.emit(room)
	_spawn_wave()


func _wave_finished() -> void:
	var state := states[active]
	state.wave += 1
	if state.wave < state.waves.size():
		_spawn_wave()
	else:
		finish_fight()


## Open the doors and mark the active room cleared. Called by the level after a boss dies.
func finish_fight() -> void:
	if active < 0:
		return
	var room := level.gen.rooms[active]
	states[active].cleared = true
	active = -1
	boss_fight = false
	level.set_doors_barred(room.door_cells(), false)
	room_cleared.emit(room)


## Treat a room as an ongoing fight without composing waves (test showcase of loose enemies).
func hold(room_id: int) -> void:
	active = room_id


# ------------------------------------------------------------------ spawning
func _spawn_wave() -> void:
	var room := level.gen.rooms[active]
	var state := states[active]
	var spots := level.gen.open_cells(room, 1)
	spots.shuffle()
	var used: Array[Vector2] = []
	for kind: String in state.waves[state.wave]:
		var pos := _pick_spot(spots, used, room)
		used.append(pos)
		spawn_telegraphed(kind, pos, level.depth)
	Sound.play("spawn", -6.0)


## First free spot that is neither on top of the player nor on top of another spawn.
func _pick_spot(spots: Array[Vector2i], used: Array[Vector2], room: DungeonRoom) -> Vector2:
	var player_pos := level.player.global_position
	for c in spots:
		var pos := NavGrid.cell_center(c)
		if pos.distance_to(player_pos) < MIN_SPAWN_DISTANCE:
			continue
		if used.any(func(other: Vector2) -> bool: return other.distance_to(pos) < SPAWN_SPACING):
			continue
		return pos
	if spots.is_empty():
		return NavGrid.cell_center(room.center)
	return NavGrid.cell_center(spots[level.rng.randi_range(0, spots.size() - 1)])


## Show a warning marker, then spawn the enemy there. Also used by bosses that summon help.
func spawn_telegraphed(kind: String, pos: Vector2, depth_level: int) -> void:
	level.telegraph(pos, SPAWN_MARKER_RADIUS, SPAWN_WARNING, SUMMON_COLOR if kind == "shade" else SPAWN_COLOR)
	var spawn := PendingSpawn.new()
	spawn.kind = kind
	spawn.pos = pos
	spawn.depth_level = depth_level
	spawn.time_left = SPAWN_WARNING
	_pending.append(spawn)


func cancel_pending() -> void:
	_pending.clear()


func _tick_pending(delta: float) -> void:
	for spawn: PendingSpawn in _pending.duplicate():
		spawn.time_left -= delta
		if spawn.time_left <= 0.0:
			_pending.erase(spawn)
			level.spawn_enemy(spawn.kind, spawn.pos, spawn.depth_level)
			Fx.burst(level.fx, spawn.pos + Vector2(0, -6), UiTheme.FOG, 8, 50, 0.35, 1.5, false)
