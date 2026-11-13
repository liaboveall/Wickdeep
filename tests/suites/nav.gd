extends "res://tests/test_suite.gd"
## NavGrid: solidity, line of sight, paths and doors.

var grid: NavGrid


## A 12x8 map with a 10x6 room and a wall across the middle that has a door in it:
##   x = 6 is solid for y 1..6, except the DOOR cell at (6, 3).
func before_each() -> void:
	var w := 12
	var h := 8
	var data := PackedByteArray()
	data.resize(w * h)
	data.fill(DungeonGen.SOLID)
	for y in range(1, 7):
		for x in range(1, 11):
			data[y * w + x] = DungeonGen.SOLID if x == 6 else DungeonGen.FLOOR
	data[3 * w + 6] = DungeonGen.DOOR
	grid = NavGrid.new()
	grid.setup(w, h, data)


func test_coordinates() -> void:
	equal(NavGrid.cell_of(Vector2(0, 0)), Vector2i(0, 0), "origin")
	equal(NavGrid.cell_of(Vector2(31.9, 16.0)), Vector2i(1, 1), "inside a cell")
	equal(NavGrid.cell_of(Vector2(-0.1, 5)), Vector2i(-1, 0), "negative side rounds down")
	equal(NavGrid.cell_center(Vector2i(2, 3)), Vector2(40, 56), "cell centre")
	equal(NavGrid.rect_to_world(Rect2i(1, 2, 3, 4)), Rect2(16, 32, 48, 64), "rect in pixels")


func test_solidity() -> void:
	check(grid.is_solid_cell(Vector2i(0, 0)), "border wall")
	check(grid.is_solid_cell(Vector2i(-3, 2)), "outside the map")
	check(grid.is_solid_cell(Vector2i(99, 2)), "outside the map (far side)")
	check(not grid.is_solid_cell(Vector2i(2, 2)), "floor")
	check(grid.is_solid_cell(Vector2i(6, 2)), "dividing wall")
	check(not grid.is_solid_cell(Vector2i(6, 3)), "open door")
	check(grid.is_solid_at(Vector2(100, 40)), "pixel in the wall")


func test_line_of_sight() -> void:
	var left := NavGrid.cell_center(Vector2i(3, 5))
	var right := NavGrid.cell_center(Vector2i(9, 5))
	check(grid.line_of_sight(left, NavGrid.cell_center(Vector2i(4, 2))), "across open floor")
	check(not grid.line_of_sight(left, right), "blocked by the wall")
	check(grid.line_of_sight(NavGrid.cell_center(Vector2i(3, 3)), NavGrid.cell_center(Vector2i(9, 3))), "through the door")


func test_paths_and_doors() -> void:
	var from := NavGrid.cell_center(Vector2i(2, 5))
	var to := NavGrid.cell_center(Vector2i(9, 5))
	var path := grid.path(from, to)
	check(path.size() > 0, "a path exists through the door")
	check(Vector2(NavGrid.cell_center(Vector2i(6, 3))) in path, "and it goes through the door cell")
	check(grid.path(from, NavGrid.cell_center(Vector2i(6, 5))).is_empty(), "no path into a wall")
	grid.set_barred([Vector2i(6, 3)], true)
	check(grid.is_solid_cell(Vector2i(6, 3)), "barred door is solid")
	check(grid.path(from, to).is_empty(), "no way through a barred door")
	check(not grid.line_of_sight(NavGrid.cell_center(Vector2i(3, 3)), NavGrid.cell_center(Vector2i(9, 3))), "nor a line of sight")
	equal(grid.value(Vector2i(6, 3)), DungeonGen.DOOR, "it is still a door cell")
	grid.set_barred([Vector2i(6, 3)], false)
	check(grid.path(from, to).size() > 0, "open again")


func test_blocking_furniture() -> void:
	grid.block(Rect2i(2, 2, 2, 1))
	check(grid.is_solid_cell(Vector2i(2, 2)) and grid.is_solid_cell(Vector2i(3, 2)), "blocked cells are solid")
	check(not grid.is_solid_cell(Vector2i(4, 2)), "neighbours untouched")
	check(grid.path(NavGrid.cell_center(Vector2i(1, 1)), NavGrid.cell_center(Vector2i(2, 2))).is_empty(), "no path onto furniture")


func test_hand_built_room() -> void:
	var camp := NavGrid.room(Camp.SIZE.x, Camp.SIZE.y, Camp.ROOM)
	for spot: Vector2i in [Camp.FIRE, Camp.WICK_SPOT, Camp.STALL, Camp.STAIRS, Camp.SPAWN]:
		check(not camp.is_solid_cell(spot), "camp landmark %s is on the floor" % spot)
	check(camp.is_solid_cell(Camp.ROOM.position - Vector2i.ONE), "walls around the camp")
	check(camp.path(NavGrid.cell_center(Camp.SPAWN), NavGrid.cell_center(Camp.STAIRS)).size() > 0, "spawn to stairs")
