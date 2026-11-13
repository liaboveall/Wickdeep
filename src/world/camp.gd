class_name Camp
extends World
## Rest area between depths: campfire, Wick (chat), Granny's stall (shop + haggling), stairs down.
## Arriving here writes the checkpoint used by "Continue".

# layout, in tiles (the whole camp fits on one screen)
const SIZE := Vector2i(30, 19)
const ROOM := Rect2i(3, 3, 24, 13)
const FIRE := Vector2i(10, 9)
const WICK_SPOT := Vector2i(12, 8)
const STALL := Vector2i(19, 9)
const STAIRS := Vector2i(22, 4)
const SPAWN := Vector2i(7, 13)
const TORCH_COLUMNS := [6, 14, 25]
const BEDROLLS: Array[Vector2i] = [Vector2i(5, 6), Vector2i(5, 11)]
const BARRELS: Array[Vector2i] = [Vector2i(24, 13), Vector2i(25, 13), Vector2i(25, 12)]

const REST_HEAL := 2
const WICK_HOVER := -16.0
const THINKING_BUBBLE_TIME := 30.0

var _wick: AnimatedSprite2D
var _bubble: SpeechBubble
var _clock := 0.0


func _ready() -> void:
	_build_layers("camp")
	combat_enabled = false
	rng.seed = Run.seed_value + Run.depth * 17
	grid = NavGrid.room(SIZE.x, SIZE.y, ROOM)
	var torches: Array[Vector2i] = []
	for x: int in TORCH_COLUMNS:
		torches.append(Vector2i(x, ROOM.position.y - 1))
	_paint_tiles(torches)
	_build_fire()
	_build_wick()
	_build_stall()
	_build_stairs()
	_build_clutter()
	spawn_player(NavGrid.cell_center(SPAWN), false)
	# the whole camp fits on screen: keep it framed instead of following the player
	camera.focus_override = Vector2(ROOM.get_center()) * TILE + Vector2(0, -6)
	camera.global_position = camera.focus_override
	add_ambient_dust(Depths.dust(biome))
	Sound.music("camp")
	hud.show_banner("营地", "前方是%s" % Run.depth_title())
	Shop.restock(rng)
	_rest()
	Run.save_checkpoint()
	_greet()


func _process(delta: float) -> void:
	_clock += delta
	_wick.position.y = WICK_HOVER + sin(_clock * 2.86) * 2.0


## The campfire heals a little, once per visit.
func _rest() -> void:
	if Run.camp.rested:
		return
	Run.camp.rested = true
	if Run.is_hurt():
		Run.heal(REST_HEAL)
		hud.toast("篝火的温暖让你恢复了 %d 点生命" % REST_HEAL, UiTheme.GOLD)


## Wick comments on the depth that was just cleared (a model writes it if one is configured).
func _greet() -> void:
	if Wick.arrival_pending():
		_bubble.say("……", THINKING_BUBBLE_TIME)
	Wick.arrival(_on_greeting)


func _on_greeting(line: String, fresh: bool) -> void:
	_bubble.say(line)
	if fresh:
		Sound.play("talk_wick", -6.0)


# ------------------------------------------------------------------ furnishing
func _build_fire() -> void:
	var fire_pos := NavGrid.cell_center(FIRE)
	var carpet := Sprite2D.new()
	carpet.texture = SpriteLib.tile_region("camp", TileFactory.CARPET, Vector2i(3, 3))
	carpet.position = fire_pos + Vector2(0, 2)
	deco.add_child(carpet)
	# the flames stand on a holder among the entities so the player can walk behind them
	var holder := Node2D.new()
	holder.position = fire_pos + Vector2(0, 4)
	entities.add_child(holder)
	var fire := SpriteLib.make_sprite("campfire", "burn")
	fire.material = Fx.unshaded()
	fire.position = Vector2(0, -10)
	holder.add_child(fire)
	var glow := Lights.flicker(Color(1.0, 0.68, 0.38), 190.0, 1.05, 1.3)
	glow.position = fire_pos
	deco.add_child(glow)
	deco.add_child(_fire_sparks(fire_pos + Vector2(0, -8)))


func _fire_sparks(pos: Vector2) -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.position = pos
	sparks.amount = 14
	sparks.lifetime = 1.6
	sparks.direction = Vector2.UP
	sparks.spread = 25.0
	sparks.gravity = Vector2(0, -12)
	sparks.initial_velocity_min = 8.0
	sparks.initial_velocity_max = 22.0
	sparks.color = UiTheme.AMBER
	sparks.material = Fx.unshaded()
	sparks.z_index = 5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	sparks.color_ramp = ramp
	return sparks


## Wick floats beside the fire, with a speech bubble above.
func _build_wick() -> void:
	var spot := NavGrid.cell_center(WICK_SPOT)
	var wick := Interactable.new()
	wick.kind = Interactable.Kind.WICK
	wick.prompt = "和灯芯说话"
	wick.radius = 24.0
	_wick = SpriteLib.make_sprite("wick", "idle")
	_wick.material = Fx.unshaded()
	_wick.position = Vector2(0, WICK_HOVER)
	wick.add_child(_wick)
	wick.add_child(ActorGfx.shadow(8))
	var glow := Lights.make(Color(1.0, 0.75, 0.4), 50.0, 0.8)
	glow.position = Vector2(0, WICK_HOVER)
	wick.add_child(glow)
	wick.used.connect(func() -> void: game.pilot.wick_chat())
	add_interactable(wick, spot)
	_bubble = SpeechBubble.new()
	_bubble.anchor = spot + Vector2(0, -34)
	_bubble.modulate.a = 0.0
	fx.add_child(_bubble)


## Granny behind her two-tile stall.
func _build_stall() -> void:
	var granny := SpriteLib.make_sprite("granny", "idle")
	granny.position = NavGrid.cell_center(STALL + Vector2i.UP) + Vector2(0, -4)
	entities.add_child(granny)
	var stall := Interactable.new()
	stall.kind = Interactable.Kind.SHOP
	stall.prompt = "和秤婆交易"
	stall.radius = 26.0
	for half in 2:
		var counter := Props.sprite("stall")
		counter.position = Vector2(16 * half, -6)
		counter.flip_h = half == 1
		stall.add_child(counter)
	var lamp := Lights.make(Color(1.0, 0.85, 0.6), 60.0, 0.7)
	lamp.position = Vector2(8, -14)
	stall.add_child(lamp)
	stall.used.connect(func() -> void: game.pilot.shop())
	add_interactable(stall, NavGrid.cell_center(STALL))
	_block(Rect2i(STALL.x, STALL.y - 1, 2, 2))


## Stairs to the next depth, with a signpost.
func _build_stairs() -> void:
	var decal := Props.stairs_decal("camp")
	decal.position = NavGrid.cell_center(STAIRS) + Vector2(8, 8)
	deco.add_child(decal)
	var stairs := Props.stairs("前往" + Run.depth_title())
	stairs.used.connect(func() -> void:
		stairs.enabled = false
		Sound.play("stairs")
		game.next_depth())
	add_interactable(stairs, NavGrid.cell_center(STAIRS) + Vector2(8, 12))
	var signpost := Props.sprite("sign")
	signpost.position = NavGrid.cell_center(STAIRS + Vector2i(-1, 1))
	entities.add_child(signpost)


func _build_clutter() -> void:
	for c in BEDROLLS:
		var bed := Props.sprite("bedroll")
		bed.position = NavGrid.cell_center(c)
		deco.add_child(bed)
	for c in BARRELS:
		var barrel := Props.sprite("barrel")
		barrel.position = NavGrid.cell_center(c) + Vector2(0, -2)
		entities.add_child(barrel)
		_block(Rect2i(c, Vector2i.ONE))


## Make a tile area solid for both path-finding and physics (furniture).
func _block(area: Rect2i) -> void:
	grid.block(area)
	var body := StaticBody2D.new()
	body.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(area.size) * TILE
	shape.shape = box
	shape.position = Vector2(area.position) * TILE + box.size / 2.0
	body.add_child(shape)
	add_child(body)
