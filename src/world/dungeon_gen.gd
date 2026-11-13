class_name DungeonGen
extends RefCounted
## Seed-deterministic dungeon layout (pure data, no nodes): the same seed and depth always give
## the same map, which is what a second player would need to generate the same dungeon.
##
## Rooms sit on a GRID x GRID macro grid; adjacent rooms are joined by 3-wide corridors whose
## doorway cells (DOOR) can be barred while a fight is on.
##
## tests/golden/baseline.json pins the output for 200 seeds. Anything that changes the order of
## rng calls here changes every map, and that test will say so.

enum { SOLID = 0, FLOOR = 1, DOOR = 2, RUBBLE = 3 }

const GRID := 5
const CELL_W := 34
const CELL_H := 24
const MARGIN := 3
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const OBSTACLE_PATTERNS := ["pillars4", "pillar_row", "center_block", "rubble", "columns", "ring", "none", "rubble"]
const EXTRA_LINK_CHANCE := 0.12

var rng := RandomNumberGenerator.new()
var w := 0
var h := 0
var grid := PackedByteArray()
var room_map := PackedInt32Array()     # tile -> room id, -1 outside rooms
var rooms: Array[DungeonRoom] = []
var edges: Array = []                  # [room id, room id] per corridor
var depth := 1
var boss := ""


func generate(seed_value: int, depth_value: int, boss_kind := "") -> void:
	depth = depth_value
	boss = boss_kind
	rng.seed = seed_value
	w = GRID * CELL_W + MARGIN * 2
	h = GRID * CELL_H + MARGIN * 2
	grid.resize(w * h)
	grid.fill(SOLID)
	room_map.resize(w * h)
	room_map.fill(-1)
	rooms.clear()
	edges.clear()
	_layout()
	_assign_types()
	_size_rooms()
	_carve()
	for room in rooms:
		if room.type == DungeonRoom.Type.COMBAT:
			_place_obstacles(room)


# ---------------------------------------------------------------- queries
func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func get_cell(c: Vector2i) -> int:
	return grid[idx(c)] if in_bounds(c) else SOLID


func set_cell(c: Vector2i, v: int) -> void:
	if in_bounds(c):
		grid[idx(c)] = v


func walkable(c: Vector2i) -> bool:
	var v := get_cell(c)
	return v == FLOOR or v == DOOR


## Id of the room containing this tile, or -1 in corridors and walls.
func room_at_cell(c: Vector2i) -> int:
	return room_map[idx(c)] if in_bounds(c) else -1


func start_room() -> DungeonRoom:
	return rooms[0]


## First room of the given type, or null.
func find_room(type: DungeonRoom.Type) -> DungeonRoom:
	for room in rooms:
		if room.type == type:
			return room
	return null


## The room the depth ends in: the boss arena on boss depths, the stairs room otherwise.
func goal_room() -> DungeonRoom:
	return find_room(DungeonRoom.Type.BOSS if boss != "" else DungeonRoom.Type.EXIT)


## Floor cells inside a room that are not next to any wall (good spawn spots).
func open_cells(room: DungeonRoom, margin := 1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rect := room.rect
	for y in range(rect.position.y + margin, rect.end.y - margin):
		for x in range(rect.position.x + margin, rect.end.x - margin):
			var c := Vector2i(x, y)
			if get_cell(c) != FLOOR:
				continue
			var open := true
			for d in DIRS:
				if not walkable(c + d):
					open = false
					break
			if open:
				out.append(c)
	return out


# ---------------------------------------------------------------- layout
## Grow a tree of rooms outwards from the middle of the macro grid, then add a few loops.
func _layout() -> void:
	var target := 7 + depth
	if depth >= 5:
		target = 7
	var taken := {}   # macro cell -> room id
	var start := Vector2i(GRID / 2, GRID / 2)
	taken[start] = 0
	rooms.append(DungeonRoom.new(0, start, DungeonRoom.Type.START))
	var tries := 0
	while rooms.size() < target and tries < 2000:
		tries += 1
		var from: int = rng.randi_range(0, rooms.size() - 1)
		var dir: Vector2i = DIRS[rng.randi_range(0, 3)]
		var c: Vector2i = rooms[from].cell + dir
		if c.x < 0 or c.y < 0 or c.x >= GRID or c.y >= GRID or taken.has(c):
			continue
		# prefer branching out over filling in: crowded cells are usually skipped
		var neighbours := 0
		for d in DIRS:
			if taken.has(c + d):
				neighbours += 1
		if neighbours > 1 and rng.randf() < 0.8:
			continue
		var id := rooms.size()
		taken[c] = id
		rooms.append(DungeonRoom.new(id, c))
		_link(from, id)
	# a few extra links make loops so the map is not a pure tree
	for room in rooms:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: int = taken.get(room.cell + d, -1)
			if other >= 0 and not other in room.links and room.id != 0 and other != 0 \
					and rng.randf() < EXTRA_LINK_CHANCE:
				_link(room.id, other)


func _link(a: int, b: int) -> void:
	rooms[a].links.append(b)
	rooms[b].links.append(a)
	edges.append([a, b])


## Breadth-first distance from the start room, stored on each room.
func _measure_distances() -> void:
	for room in rooms:
		room.dist = -1
	rooms[0].dist = 0
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for next in rooms[cur].links:
			if rooms[next].dist < 0:
				rooms[next].dist = rooms[cur].dist + 1
				queue.append(next)


## The farthest dead end becomes the exit (or boss arena); the next ones treasure and shrine.
func _assign_types() -> void:
	_measure_distances()
	var dead_ends: Array[int] = []
	for room in rooms:
		if room.id != 0 and room.links.size() == 1:
			dead_ends.append(room.id)
	dead_ends.sort_custom(func(a: int, b: int) -> bool: return rooms[a].dist > rooms[b].dist)
	var exit_id: int
	if dead_ends.is_empty():
		var far := 1
		for room in rooms:
			if room.dist > rooms[far].dist:
				far = room.id
		exit_id = far
	else:
		exit_id = dead_ends.pop_front()
	rooms[exit_id].type = DungeonRoom.Type.BOSS if boss != "" else DungeonRoom.Type.EXIT
	if not dead_ends.is_empty():
		rooms[dead_ends.pop_front()].type = DungeonRoom.Type.TREASURE
	else:
		for room in rooms:
			if room.type == DungeonRoom.Type.COMBAT and room.links.size() <= 2:
				room.type = DungeonRoom.Type.TREASURE
				break
	if not dead_ends.is_empty() and depth < 5:
		rooms[dead_ends.pop_front()].type = DungeonRoom.Type.SHRINE


func _size_rooms() -> void:
	for room in rooms:
		var size: Vector2i
		match room.type:
			DungeonRoom.Type.START:
				size = Vector2i(13, 9)
			DungeonRoom.Type.TREASURE, DungeonRoom.Type.SHRINE:
				size = Vector2i(11, 8)
			DungeonRoom.Type.EXIT:
				size = Vector2i(14, 10)
			DungeonRoom.Type.BOSS:
				size = Vector2i(28, 18) if boss == "matron" else Vector2i(30, 19)
			_:
				var rw := rng.randi_range(15, 25)
				size = Vector2i(rw, rng.randi_range(10, 15))
		var centre := Vector2i(MARGIN + room.cell.x * CELL_W + CELL_W / 2, MARGIN + room.cell.y * CELL_H + CELL_H / 2)
		room.center = centre
		room.rect = Rect2i(centre - size / 2, size)


func _carve() -> void:
	for room in rooms:
		var rect := room.rect
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				set_cell(Vector2i(x, y), FLOOR)
				room_map[idx(Vector2i(x, y))] = room.id
	for edge: Array in edges:
		var a := rooms[edge[0]]
		var b := rooms[edge[1]]
		if a.cell.x > b.cell.x or a.cell.y > b.cell.y:
			var swap := a
			a = b
			b = swap
		if a.cell.y == b.cell.y:
			_carve_corridor(a, b, Vector2i(1, 0))    # side by side, a on the left
		else:
			_carve_corridor(a, b, Vector2i(0, 1))    # stacked, a above


## Dig a 3-wide corridor from `a` to `b` along `dir`; its first and last rows become doors.
func _carve_corridor(a: DungeonRoom, b: DungeonRoom, dir: Vector2i) -> void:
	var across := Vector2i(dir.y, dir.x)
	var door_a: Array[Vector2i] = []
	var door_b: Array[Vector2i] = []
	var first: int
	var last: int
	var lane: Vector2i   # the corridor's middle line, as an offset on the other axis
	if dir.x != 0:
		first = a.rect.end.x
		last = b.rect.position.x - 1
		lane = Vector2i(0, a.center.y)
	else:
		first = a.rect.end.y
		last = b.rect.position.y - 1
		lane = Vector2i(a.center.x, 0)
	for along in range(first, last + 1):
		for side in range(-1, 2):
			var c := lane + dir * along + across * side
			if along == first:
				set_cell(c, DOOR)
				door_a.append(c)
			elif along == last:
				set_cell(c, DOOR)
				door_b.append(c)
			else:
				set_cell(c, FLOOR)
	a.add_door(dir, door_a, b.id)
	b.add_door(-dir, door_b, a.id)


# ---------------------------------------------------------------- obstacles
func _place_obstacles(room: DungeonRoom) -> void:
	var rect := room.rect
	var rw := rect.size.x
	var rh := rect.size.y
	var keep := _door_lanes(room)
	var pattern: String = OBSTACLE_PATTERNS[rng.randi_range(0, OBSTACLE_PATTERNS.size() - 1)]
	var changes: Array = []   # [cell, value]
	var put := func(lx: int, ly: int, v: int) -> void:
		if lx < 2 or ly < 2 or lx > rw - 3 or ly > rh - 3:
			return
		var c := rect.position + Vector2i(lx, ly)
		if keep.has(c):
			return
		changes.append([c, v])
	match pattern:
		"pillars4":
			for p: Vector2i in [Vector2i(rw / 4, rh / 4), Vector2i(rw * 3 / 4 - 1, rh / 4),
					Vector2i(rw / 4, rh * 3 / 4 - 1), Vector2i(rw * 3 / 4 - 1, rh * 3 / 4 - 1)]:
				for dy in 2:
					for dx in 2:
						put.call(p.x + dx, p.y + dy, SOLID)
		"pillar_row":
			var y := rh / 2
			for x in range(3, rw - 3, 3):
				if absi(x - rw / 2) > 1:
					put.call(x, y, SOLID)
		"center_block":
			var bw := maxi(2, rw / 4)
			var bh := maxi(2, rh / 4)
			for y in range(rh / 2 - bh / 2, rh / 2 - bh / 2 + bh):
				for x in range(rw / 2 - bw / 2, rw / 2 - bw / 2 + bw):
					put.call(x, y, SOLID)
		"columns":
			for x: int in [rw / 3, rw * 2 / 3]:
				for y in range(rh / 3, rh - rh / 3):
					put.call(x, y, SOLID)
		"ring":
			var cx := rw / 2
			var cy := rh / 2
			for k in 8:
				var a := k * TAU / 8.0
				put.call(cx + int(round(cos(a) * rw * 0.28)), cy + int(round(sin(a) * rh * 0.3)), SOLID)
		"rubble":
			for k in rng.randi_range(5, 10):
				put.call(rng.randi_range(2, rw - 3), rng.randi_range(2, rh - 3), RUBBLE)
	for change: Array in changes:
		set_cell(change[0], change[1])
	# never let obstacles cut a room in two: if they do, take them all back out
	if not _room_connected(room):
		for change: Array in changes:
			set_cell(change[0], FLOOR)
		pattern = "none"
	room.pattern = pattern


## Cells within three tiles of a doorway stay clear so nobody is ever blocked at an entrance.
func _door_lanes(room: DungeonRoom) -> Dictionary:
	var keep := {}
	for door in room.doors:
		for c in door.cells:
			for k in range(1, 4):
				var inner: Vector2i = c - door.dir * k
				for o in range(-1, 2):
					keep[inner + Vector2i(door.dir.y, door.dir.x) * o] = true
	return keep


## True if every walkable cell of the room, and each of its doors, can be reached from any other.
func _room_connected(room: DungeonRoom) -> bool:
	var rect := room.rect
	var start := Vector2i(-1, -1)
	var total := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if walkable(c):
				total += 1
				if start.x < 0:
					start = c
	if start.x < 0:
		return false
	var reach := rect.grow(1)   # one tile out, so the doorway cells are included
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in DIRS:
			var n: Vector2i = c + d
			if seen.has(n) or not walkable(n) or not reach.has_point(n):
				continue
			seen[n] = true
			stack.append(n)
	for c in room.door_cells():
		if not seen.has(c):
			return false
	var inside := 0
	for c: Vector2i in seen:
		if rect.has_point(c):
			inside += 1
	return inside >= total
