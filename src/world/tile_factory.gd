class_name TileFactory
extends RefCounted
## Builds a TileSet (with collision) from a generated biome atlas, and paints a grid onto
## TileMapLayers with simple 3/4-view wall autotiling. Atlas layout: see tools/assetgen/tiles.py.

const T := 16
const ATLAS_COLUMNS := 8
const ATLAS_ROWS := 10

# atlas rows
const ROW_FLOOR := 0
const ROW_SHADOW := 1     # columns 0-3: floor in the shadow of a wall; 4-7: cracked floor
const ROW_FACE := 2
const ROW_TOP := 3
const ROW_RIM := 4        # two rows of wall-top edges, indexed by a 4-bit neighbour mask
const ROW_SIDE := 6
# single tiles
const RUBBLE_A := Vector2i(4, 3)
const RUBBLE_B := Vector2i(5, 3)
const BARS := Vector2i(6, 3)
const STAIRS := Vector2i(0, 7)
const CARPET := Vector2i(2, 7)
# wall face variants (columns of ROW_FACE)
const FACE_TORCH := 4
const FACE_RARE := 5
const FACE_ODD := 6

## How a solid cell next to open floor is drawn.
enum Wall { NONE, FACE, TOP }

static var _cache := {}


static func tileset(biome: String) -> TileSet:
	if _cache.has(biome):
		return _cache[biome]
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, PhysicsLayers.WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = SpriteLib.texture("tiles_" + biome)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var half := T / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	var boulder := PackedVector2Array()
	for k in 8:
		boulder.append(Vector2.from_angle(k * TAU / 8.0 + TAU / 16.0) * 6.5)
	for y in ATLAS_ROWS:
		for x in ATLAS_COLUMNS:
			var c := Vector2i(x, y)
			src.create_tile(c)
			if y == ROW_FACE or (y == ROW_TOP and x <= 6):
				var data := src.get_tile_data(c, 0)
				data.add_collision_polygon(0)
				data.set_collision_polygon_points(0, 0, boulder if (c == RUBBLE_A or c == RUBBLE_B) else square)
	_cache[biome] = ts
	return ts


## Paint floor, walls and wall overlays for `grid` onto the given layers.
## `special_faces` maps wall cells to a fixed face variant (torch brackets).
## The rng is consumed in a fixed order, so the same seed always paints the same level.
static func paint(grid: NavGrid, floor_l: TileMapLayer, wall_l: TileMapLayer, over_l: TileMapLayer,
		rng: RandomNumberGenerator, special_faces: Dictionary = {}) -> void:
	var walls := _classify_walls(grid)
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			var v := grid.value(c)
			if v == DungeonGen.SOLID:
				continue
			var atlas: Vector2i
			if walls.get(c + Vector2i.UP, Wall.NONE) == Wall.FACE:
				atlas = Vector2i(rng.randi_range(0, 3), ROW_SHADOW)
			elif rng.randf() < 0.07:
				atlas = Vector2i(4 + rng.randi_range(0, 3), ROW_SHADOW)
			else:
				atlas = Vector2i(rng.randi_range(0, 7), ROW_FLOOR)
			floor_l.set_cell(c, 0, atlas)
			if v == DungeonGen.RUBBLE:
				wall_l.set_cell(c, 0, RUBBLE_A if rng.randf() < 0.5 else RUBBLE_B)
	for c: Vector2i in walls:
		if walls[c] == Wall.FACE:
			_paint_face(grid, c, wall_l, over_l, rng, special_faces.get(c, -1))
		else:
			_paint_top(grid, c, walls, wall_l, over_l, rng)


## Decide which solid cells are visible: a FACE if there is floor right below, otherwise a TOP.
static func _classify_walls(grid: NavGrid) -> Dictionary:
	var walls := {}
	for y in grid.h:
		for x in grid.w:
			var c := Vector2i(x, y)
			if _open(grid, c):
				continue
			var near_floor := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if _open(grid, c + Vector2i(dx, dy)):
						near_floor = true
			if near_floor:
				walls[c] = Wall.FACE if _open(grid, c + Vector2i.DOWN) else Wall.TOP
	# cap faces with a top tile above them so walls read as blocks
	for c: Vector2i in walls.keys():
		if walls[c] == Wall.FACE:
			var up := c + Vector2i.UP
			if not _open(grid, up) and not walls.has(up):
				walls[up] = Wall.TOP
	return walls


static func _open(grid: NavGrid, c: Vector2i) -> bool:
	return grid.value(c) != DungeonGen.SOLID


static func _paint_face(grid: NavGrid, c: Vector2i, wall_l: TileMapLayer, over_l: TileMapLayer,
		rng: RandomNumberGenerator, variant: int) -> void:
	if variant < 0:
		var roll := rng.randf()
		variant = rng.randi_range(0, 3)
		if roll < 0.07:
			variant = FACE_RARE
		elif roll < 0.16:
			variant = FACE_ODD + rng.randi_range(0, 1)
	wall_l.set_cell(c, 0, Vector2i(variant, ROW_FACE))
	# darker edge where the face ends at a floor cell to the left or right
	var left := _open(grid, c + Vector2i.LEFT)
	var right := _open(grid, c + Vector2i.RIGHT)
	if left or right:
		var side := 2 if (left and right) else (0 if left else 1)
		over_l.set_cell(c, 0, Vector2i(side, ROW_SIDE))


static func _paint_top(grid: NavGrid, c: Vector2i, walls: Dictionary, wall_l: TileMapLayer,
		over_l: TileMapLayer, rng: RandomNumberGenerator) -> void:
	wall_l.set_cell(c, 0, Vector2i(rng.randi_range(0, 3), ROW_TOP))
	# rim on every side that borders floor or a wall face
	var mask := 0
	var bit := 1
	for d: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var n := c + d
		if _open(grid, n) or walls.get(n, Wall.NONE) == Wall.FACE:
			mask |= bit
		bit <<= 1
	if mask != 0:
		over_l.set_cell(c, 0, Vector2i(mask % 8, ROW_RIM + mask / 8))
