class_name World
extends Node2D
## Shared base for dungeon levels and the camp: the tile layers, the containers everything is
## spawned into, lighting, the camera and the HUD, plus the queries actors make about each other.

const TILE := NavGrid.TILE

# draw order of the node layers (the y-sorted entities sit at 0)
const Z_FLOOR := -30
const Z_WALLS := -29
const Z_WALL_OVERLAY := -28
const Z_DOORS := -27
const Z_DECO := -20
const Z_PROJECTILES := 10
const Z_DUST := 15
const Z_FX := 20

var game: Game
var biome := "moss"
var ambient := Color(0.32, 0.31, 0.4)
var grid: NavGrid
var rng := RandomNumberGenerator.new()
var combat_enabled := true

var player: Player
var enemies: Array[Enemy] = []
var props: Array[Breakable] = []
var interactables: Array[Interactable] = []

var darkness: CanvasModulate
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var overlay_layer: TileMapLayer
var door_layer: TileMapLayer
var deco: Node2D          # floor decals, torches, telegraphs
var entities: Node2D      # y-sorted actors and props
var projectiles: Node2D
var fx: Node2D
var camera: GameCamera
var hud: Hud
var _focus: Interactable


# ------------------------------------------------------------------ construction
func _build_layers(biome_name: String) -> void:
	biome = biome_name
	ambient = Depths.ambient(biome)
	darkness = CanvasModulate.new()
	darkness.color = ambient
	add_child(darkness)
	var tiles := TileFactory.tileset(biome)
	floor_layer = _tile_layer(tiles, Z_FLOOR, false)
	wall_layer = _tile_layer(tiles, Z_WALLS, true)
	overlay_layer = _tile_layer(tiles, Z_WALL_OVERLAY, false)
	door_layer = _tile_layer(tiles, Z_DOORS, true)
	deco = _container("Deco", Z_DECO)
	entities = _container("Entities", 0)
	entities.y_sort_enabled = true
	projectiles = _container("Projectiles", Z_PROJECTILES)
	fx = _container("Fx", Z_FX)
	camera = GameCamera.new()
	add_child(camera)
	hud = Hud.new()
	hud.world = self
	add_child(hud)


func _tile_layer(tiles: TileSet, z: int, collide: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = tiles
	layer.z_index = z
	layer.collision_enabled = collide
	layer.rendering_quadrant_size = 32
	add_child(layer)
	return layer


func _container(node_name: String, z: int) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	node.z_index = z
	add_child(node)
	return node


## Draw the grid onto the tile layers, with a lit torch on each of the given wall cells.
func _paint_tiles(torch_cells: Array[Vector2i]) -> void:
	var brackets := {}
	for c in torch_cells:
		brackets[c] = TileFactory.FACE_TORCH
	TileFactory.paint(grid, floor_layer, wall_layer, overlay_layer, rng, brackets)
	for c in torch_cells:
		add_torch(NavGrid.cell_center(c) + Vector2(0, -6))


func spawn_player(pos: Vector2, armed := true) -> Player:
	player = Player.new()
	player.world = self
	player.input = game.pilot.make_input()
	player.god = game.options.god
	player.combat = armed
	player.position = pos
	player.damaged.connect(hud.flash_damage)
	entities.add_child(player)
	camera.target = player
	camera.snap_to_target()
	hud.player = player
	return player


## Run `callback` after `seconds` of game time. Unlike a scene-tree timer this pauses with the
## game and is simply dropped if the world is freed first.
func after(seconds: float, callback: Callable) -> void:
	create_tween().tween_callback(callback).set_delay(seconds)


# ------------------------------------------------------------------ doors
func set_doors_barred(door_cells: Array, barred: bool) -> void:
	grid.set_barred(door_cells, barred)
	for c: Vector2i in door_cells:
		if barred:
			door_layer.set_cell(c, 0, TileFactory.BARS)
		else:
			door_layer.erase_cell(c)


# ------------------------------------------------------------------ enemies and bullets
func spawn_enemy(kind: String, pos: Vector2, depth_level := 1) -> Enemy:
	var enemy := Bestiary.create(kind)
	enemy.world = self
	enemy.depth_level = depth_level
	enemy.position = pos
	enemy.died.connect(_on_enemy_died)
	entities.add_child(enemy)
	enemies.append(enemy)
	return enemy


func _on_enemy_died(enemy: Enemy) -> void:
	enemies.erase(enemy)


func add_projectile(p: Projectile) -> void:
	p.world = self
	projectiles.add_child(p)


func enemy_shot(sheet: String, from: Vector2, dir: Vector2, speed: float, source: String, damage := 1,
		radius := 3.0) -> Projectile:
	var p := Projectile.hostile(sheet, from, dir.normalized() * speed * Run.stats.enemy_bullet_speed, source,
		damage, radius)
	add_projectile(p)
	return p


func enemy_bullets() -> Array[Projectile]:
	var out: Array[Projectile] = []
	for node in projectiles.get_children():
		var p := node as Projectile
		if p and p.team == Projectile.Team.ENEMY and not p.dead:
			out.append(p)
	return out


func clear_enemy_bullets(center: Vector2, radius: float) -> int:
	var cleared := 0
	for p in enemy_bullets():
		if p.position.distance_to(center) <= radius:
			p.die(true)
			cleared += 1
	return cleared


## Closest enemy that can be hit right now, or null.
func nearest_enemy(pos: Vector2, max_dist := 99999.0) -> Enemy:
	var best: Enemy = null
	var best_dist := max_dist
	for e in enemies:
		if e.dead or e.spawning():
			continue
		var d := e.global_position.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = e
	return best


## Warn the player that something is about to land or appear at `pos`.
func telegraph(pos: Vector2, radius: float, duration: float, color: Color) -> Fx.Telegraph:
	var marker := Fx.Telegraph.new()
	marker.radius = radius
	marker.duration = duration
	marker.color = color
	marker.position = pos
	deco.add_child(marker)
	return marker


# ------------------------------------------------------------------ pickups
func drop_embers(pos: Vector2, count: int) -> void:
	count = int(round(count * Run.stats.ember_mult))
	for i in count:
		_drop(Pickup.Kind.EMBER, pos, randf_range(40, 110))


func drop_oil(pos: Vector2) -> void:
	_drop(Pickup.Kind.OIL, pos, 50.0)


func _drop(kind: Pickup.Kind, pos: Vector2, speed: float) -> void:
	var pickup := Pickup.new()
	pickup.kind = kind
	pickup.world = self
	pickup.position = pos
	pickup.vel = Vector2.from_angle(randf() * TAU) * speed
	entities.add_child(pickup)


## Pull every loose ember to the player (after a room is cleared).
func magnet_all() -> void:
	for node in entities.get_children():
		var pickup := node as Pickup
		if pickup and pickup.kind == Pickup.Kind.EMBER:
			pickup.magnet = true


# ------------------------------------------------------------------ interaction
func add_interactable(it: Interactable, pos: Vector2) -> Interactable:
	it.position = pos
	entities.add_child(it)
	interactables.append(it)
	return it


func add_breakable(b: Breakable, pos: Vector2) -> void:
	b.world = self
	b.position = pos
	entities.add_child(b)
	props.append(b)


## Called by the player every frame: find the usable thing in reach and show its prompt.
func update_interaction(p: Player) -> void:
	_focus = null
	var best_dist := INF
	for it in interactables:
		if not is_instance_valid(it) or not it.enabled:
			continue
		var d := it.global_position.distance_to(p.global_position)
		if d < it.radius and d < best_dist:
			best_dist = d
			_focus = it
	hud.set_prompt(_focus)


func try_interact() -> void:
	if is_instance_valid(_focus) and _focus.enabled:
		_focus.use()


# ------------------------------------------------------------------ lighting and atmosphere
func add_torch(pos: Vector2, radius := 115.0, color := Color(1.0, 0.7, 0.4)) -> void:
	var flame := SpriteLib.make_sprite("torch", "burn")
	flame.position = pos
	flame.material = Fx.unshaded()
	flame.z_index = 1
	flame.frame = randi() % 4
	deco.add_child(flame)
	var glow := Lights.flicker(color, radius, 1.1)
	glow.position = pos + Vector2(0, 4)
	deco.add_child(glow)


## Motes drifting across the screen (they ride on the camera, not the world).
func add_ambient_dust(color: Color) -> void:
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(340, 200)
	p.direction = Vector2(0.3, -1)
	p.spread = 40.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 7.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	p.color = color
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	p.material = Fx.unshaded()
	p.z_index = Z_DUST
	p.local_coords = false
	camera.add_child(p)
