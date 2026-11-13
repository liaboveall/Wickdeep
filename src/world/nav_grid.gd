class_name NavGrid
extends RefCounted
## Tile-level collision and path queries for one level: what is solid, what can see what, and how
## to walk from A to B. Actors, bullets, pickups and the test bot all ask here, so there is one
## answer to "is this a wall" (including doors that are barred during a fight).

const TILE := 16
const SIGHT_STEP := 6.0   # pixels between samples along a line of sight

var w := 0
var h := 0
var cells := PackedByteArray()   # DungeonGen cell values, row by row
var _barred := {}                # door cells that are locked right now
var _astar := AStarGrid2D.new()


func setup(width: int, height: int, data: PackedByteArray) -> void:
	w = width
	h = height
	cells = data
	_barred.clear()
	_astar.region = Rect2i(0, 0, w, h)
	_astar.cell_size = Vector2(TILE, TILE)
	_astar.offset = Vector2(TILE, TILE) * 0.5
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in h:
		for x in w:
			if is_solid_cell(Vector2i(x, y)):
				_astar.set_point_solid(Vector2i(x, y), true)


## A grid that is solid everywhere except `open`, for hand-built places like the camp.
static func room(width: int, height: int, open: Rect2i) -> NavGrid:
	var data := PackedByteArray()
	data.resize(width * height)
	data.fill(DungeonGen.SOLID)
	for y in range(open.position.y, open.end.y):
		for x in range(open.position.x, open.end.x):
			data[y * width + x] = DungeonGen.FLOOR
	var grid := NavGrid.new()
	grid.setup(width, height, data)
	return grid


# ------------------------------------------------------------------ coordinates
static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


static func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * TILE


static func rect_to_world(r: Rect2i) -> Rect2:
	return Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE)


# ------------------------------------------------------------------ queries
func value(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return DungeonGen.SOLID
	return cells[c.y * w + c.x]


func is_solid_cell(c: Vector2i) -> bool:
	var v := value(c)
	return v == DungeonGen.SOLID or v == DungeonGen.RUBBLE or (v == DungeonGen.DOOR and _barred.has(c))


func is_solid_at(p: Vector2) -> bool:
	return is_solid_cell(cell_of(p))


func line_of_sight(a: Vector2, b: Vector2) -> bool:
	var d := b - a
	var steps := int(d.length() / SIGHT_STEP) + 1
	for i in range(1, steps):
		if is_solid_at(a + d * (float(i) / steps)):
			return false
	return true


## Waypoints (cell centres) from one position to another; empty if either end is in a wall.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := cell_of(from)
	var b := cell_of(to)
	if not _astar.is_in_boundsv(a) or not _astar.is_in_boundsv(b):
		return PackedVector2Array()
	if _astar.is_point_solid(a) or _astar.is_point_solid(b):
		return PackedVector2Array()
	return _astar.get_point_path(a, b)


# ------------------------------------------------------------------ changes
## Bar or open doorway cells (they stay DOOR cells; only their solidity changes).
func set_barred(door_cells: Array, barred: bool) -> void:
	for c: Vector2i in door_cells:
		if barred:
			_barred[c] = true
		else:
			_barred.erase(c)
		_astar.set_point_solid(c, barred)


## Make cells permanently solid (furniture placed after the grid was built).
func block(area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			cells[y * w + x] = DungeonGen.RUBBLE
			_astar.set_point_solid(Vector2i(x, y), true)
