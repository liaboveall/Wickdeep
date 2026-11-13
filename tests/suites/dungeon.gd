extends "res://tests/test_suite.gd"
## Properties every generated layout must have, checked over 120 seeds per depth.

const SEEDS := 120


func test_layouts_are_playable() -> void:
	for depth in range(1, Depths.FINAL + 1):
		for s in SEEDS:
			var gen := DungeonGen.new()
			gen.generate(s * 7919 + depth, depth, Depths.boss(depth))
			_check_layout(gen, "depth %d seed %d" % [depth, s])


func _check_layout(gen: DungeonGen, tag: String) -> void:
	check(gen.rooms.size() >= 5, tag + ": too few rooms (%d)" % gen.rooms.size())
	check(gen.start_room().type == DungeonRoom.Type.START, tag + ": room 0 is not the start")
	check(gen.find_room(DungeonRoom.Type.TREASURE) != null, tag + ": no treasure room")
	var goal := gen.goal_room()
	check(goal != null, tag + ": no exit / boss room")
	if goal:
		# the way out must be a little walk away from the start
		check(goal.dist >= 2, tag + ": exit too close to start (dist %d)" % goal.dist)
	var reached := _flood(gen, gen.start_room().center)
	check(gen.walkable(gen.start_room().center), tag + ": start centre blocked")
	for room in gen.rooms:
		# every walkable cell of every room must be reachable from the start
		var total := 0
		var found := 0
		for y in range(room.rect.position.y, room.rect.end.y):
			for x in range(room.rect.position.x, room.rect.end.x):
				if gen.walkable(Vector2i(x, y)):
					total += 1
					if reached.has(Vector2i(x, y)):
						found += 1
		check(total > 0 and found == total, tag + ": room %d (%s) reach %d/%d" % [room.id, room.type_name(), found, total])
		if room.type == DungeonRoom.Type.COMBAT:
			check(gen.open_cells(room, 1).size() >= 12, tag + ": combat room %d has too little open floor" % room.id)
		check(room.doors.size() == room.links.size(), tag + ": room %d doors do not match its links" % room.id)
		for door in room.doors:
			check(door.cells.size() == 3, tag + ": door not 3 wide")
			check(door.to in room.links, tag + ": door leads to an unlinked room")


func _flood(gen: DungeonGen, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var stack: Array[Vector2i] = [from]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in DungeonGen.DIRS:
			var n := c + d
			if not seen.has(n) and gen.walkable(n):
				seen[n] = true
				stack.append(n)
	return seen


func test_same_seed_same_map() -> void:
	const Golden := preload("res://tests/golden.gd")
	for depth in [1, 2, 5]:
		var a := DungeonGen.new()
		var b := DungeonGen.new()
		a.generate(4321, depth, Depths.boss(depth))
		b.generate(4321, depth, Depths.boss(depth))
		equal(Golden.fingerprint(a), Golden.fingerprint(b), "depth %d: two runs of one seed" % depth)
		b.generate(4322, depth, Depths.boss(depth))
		check(Golden.fingerprint(a) != Golden.fingerprint(b), "depth %d: another seed gives another map" % depth)


func test_boss_depths_have_an_arena() -> void:
	for depth in range(1, Depths.FINAL + 1):
		var gen := DungeonGen.new()
		gen.generate(77, depth, Depths.boss(depth))
		var has_boss_room := gen.find_room(DungeonRoom.Type.BOSS) != null
		equal(has_boss_room, Depths.boss(depth) != "", "depth %d boss room" % depth)
		equal(gen.find_room(DungeonRoom.Type.EXIT) != null, not has_boss_room, "depth %d plain exit" % depth)


func test_room_lookup() -> void:
	var gen := DungeonGen.new()
	gen.generate(9, 1)
	for room in gen.rooms:
		equal(gen.room_at_cell(room.center), room.id, "room %d contains its own centre" % room.id)
	equal(gen.room_at_cell(Vector2i(-5, -5)), -1, "outside the map")
	equal(gen.get_cell(Vector2i(-5, -5)), DungeonGen.SOLID, "outside the map is solid")
