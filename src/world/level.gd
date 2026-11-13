class_name Level
extends World
## One depth of the dungeon: builds the generated layout, furnishes the rooms (altars, shrine,
## stairs, breakables) and reacts to what RoomDirector reports: rewards, boss fights, the way down.

const SEED_PRIME_RUN := 7919
const SEED_PRIME_DEPTH := 104729
const SHRINE_HEAL := 2
const EMPTY_ALTAR_EMBERS := 30
const OIL_DROP_CHANCE := 0.14        # after clearing a room while hurt
const BOSS_EMBERS := 26
const BOSS_INTRO_TIME := 1.1         # the camera lingers on the boss
const VICTORY_DELAY := 2.6
const STAIRS_DELAY := 1.2
const SNUFF_LIGHT := 0.5             # how far the Snuffer squeezes the lantern
const SNUFF_AMBIENT := 0.68

var gen: DungeonGen
var depth := 1
var boss_kind := ""
var boss: Boss
var director: RoomDirector
var stairs: Interactable
var _snuff_t := 0.0


func _ready() -> void:
	depth = Run.depth
	boss_kind = Depths.boss(depth)
	_build_layers(Run.biome())
	rng.seed = Run.seed_value * SEED_PRIME_RUN + depth * SEED_PRIME_DEPTH
	gen = DungeonGen.new()
	gen.generate(rng.seed, depth, boss_kind)
	grid = NavGrid.new()
	grid.setup(gen.w, gen.h, gen.grid)
	_paint_tiles(_choose_torches())
	director = RoomDirector.new()
	director.setup(self)
	director.room_entered.connect(_on_room_entered)
	director.fight_started.connect(_on_fight_started)
	director.room_cleared.connect(_on_room_cleared)
	add_child(director)
	for room in gen.rooms:
		_furnish(room)
	# boss depths always offer one heal before the fight
	if boss_kind != "" and gen.find_room(DungeonRoom.Type.SHRINE) == null:
		_add_shrine(NavGrid.cell_center(gen.start_room().rect.position + Vector2i(2, 1)))
	spawn_player(NavGrid.cell_center(gen.start_room().center) + Vector2(0, 8))
	player.died.connect(func() -> void: game.finish_run(false))
	add_ambient_dust(Depths.dust(biome))
	hud.show_banner(Run.depth_title(), "击败熄灯者，重燃圣火" if Depths.is_final(depth) else "")
	Sound.music(biome)
	if depth == 1 and SaveData.runs <= 2:
		hud.show_controls_hint()


func _physics_process(delta: float) -> void:
	if _snuff_t > 0.0:
		_snuff_t -= delta
		if _snuff_t <= 0.0:
			_restore_light()


## The boss arena in world coordinates (bosses keep their jumps and summons inside it).
func boss_arena() -> Rect2:
	var room := gen.find_room(DungeonRoom.Type.BOSS)
	if room == null:
		return Rect2(player.global_position - Vector2(150, 100), Vector2(300, 200))
	return NavGrid.rect_to_world(room.rect)


func spawn_enemy_telegraphed(kind: String, pos: Vector2, depth_level: int) -> void:
	director.spawn_telegraphed(kind, pos, depth_level)


# ------------------------------------------------------------------ furnishing
## A torch bracket every few tiles along the top wall of each room.
func _choose_torches() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for room in gen.rooms:
		var y := room.rect.position.y - 1
		var step := 6 if room.type == DungeonRoom.Type.BOSS else 5
		var x := room.rect.position.x + 2
		while x < room.rect.end.x - 1:
			var c := Vector2i(x, y)
			if gen.get_cell(c) == DungeonGen.SOLID and gen.walkable(c + Vector2i.DOWN):
				out.append(c)
			x += step
	return out


func _furnish(room: DungeonRoom) -> void:
	var center := NavGrid.cell_center(room.center)
	match room.type:
		DungeonRoom.Type.TREASURE:
			var altar := Props.altar()
			altar.used.connect(_use_altar.bind(altar))
			add_interactable(altar, center)
		DungeonRoom.Type.SHRINE:
			_add_shrine(center)
		DungeonRoom.Type.EXIT:
			_add_stairs(center)
		DungeonRoom.Type.COMBAT:
			_place_breakables(room)
			if rng.randf() < 0.5:
				_place_decor("skulls", _random_wall_cell(room))


func _add_shrine(pos: Vector2) -> void:
	var shrine := Props.shrine()
	shrine.used.connect(_use_shrine.bind(shrine))
	add_interactable(shrine, pos)


func _add_stairs(center: Vector2) -> void:
	var decal := Props.stairs_decal(biome)
	decal.position = center
	deco.add_child(decal)
	stairs = Props.stairs("离开深渊" if Depths.is_final(depth) else "走下楼梯")
	stairs.used.connect(_descend)
	add_interactable(stairs, center + Vector2(0, 4))
	var glow := Lights.make(Props.STAIRS_GLOW, 60.0, 0.7)
	glow.position = center
	deco.add_child(glow)


func _place_breakables(room: DungeonRoom) -> void:
	for i in rng.randi_range(0, 3):
		var c := _random_wall_cell(room)
		if c == Vector2i(-1, -1):
			continue
		add_breakable(Props.breakable("pot" if rng.randf() < 0.7 else "barrel"), NavGrid.cell_center(c) + Vector2(0, 5))


func _place_decor(prop: String, c: Vector2i) -> void:
	if c == Vector2i(-1, -1):
		return
	var s := Props.sprite(prop)
	s.position = NavGrid.cell_center(c)
	deco.add_child(s)


## A free floor cell along the room's edge, away from the doors; (-1, -1) if none turned up.
func _random_wall_cell(room: DungeonRoom) -> Vector2i:
	var rect := room.rect
	var doorways := room.door_cells()
	for attempt in 30:
		var c: Vector2i
		match rng.randi_range(0, 3):
			0:
				c = Vector2i(rng.randi_range(rect.position.x + 1, rect.end.x - 2), rect.position.y)
			1:
				c = Vector2i(rng.randi_range(rect.position.x + 1, rect.end.x - 2), rect.end.y - 1)
			2:
				c = Vector2i(rect.position.x, rng.randi_range(rect.position.y + 1, rect.end.y - 2))
			_:
				c = Vector2i(rect.end.x - 1, rng.randi_range(rect.position.y + 1, rect.end.y - 2))
		if gen.get_cell(c) != DungeonGen.FLOOR:
			continue
		if not doorways.any(func(door: Vector2i) -> bool: return Vector2(door).distance_to(Vector2(c)) < 3.5):
			return c
	return Vector2i(-1, -1)


# ------------------------------------------------------------------ room events
func _on_room_entered(_room: DungeonRoom) -> void:
	player.shade_ready = true
	hud.queue_minimap()


func _on_fight_started(room: DungeonRoom) -> void:
	Sound.play("door_close")
	Juice.shake(0.2)
	if room.type == DungeonRoom.Type.BOSS:
		_start_boss(room)


func _on_room_cleared(room: DungeonRoom) -> void:
	Run.rooms_cleared += 1
	Sound.play("door_open")
	hud.toast("房间已清理", UiTheme.CREAM)
	if room.type == DungeonRoom.Type.COMBAT:
		drop_embers(player.global_position + Vector2(0, -20), rng.randi_range(3, 6))
		if Run.is_hurt() and rng.randf() < OIL_DROP_CHANCE:
			drop_oil(player.global_position + Vector2(0, -24))
	magnet_all()
	hud.queue_minimap()


# ------------------------------------------------------------------ interactables
func _use_altar(altar: Interactable) -> void:
	var picks := Relics.roll(rng, Run.relics, 3)
	if picks.is_empty():
		Run.add_embers(EMPTY_ALTAR_EMBERS)
		hud.toast("祭坛空了，只留下 %d 余烬" % EMPTY_ALTAR_EMBERS, UiTheme.GOLD)
		altar.spend()
		return
	game.pilot.choose_relic(picks, _take_relic.bind(altar))


func _take_relic(id: String, altar: Interactable) -> void:
	if id == "":
		return
	Run.add_relic(id)
	Sound.play("relic")
	altar.spend(SpriteLib.region("props", "altar_used"), 0.25)
	Fx.ring(fx, altar.global_position + Vector2(0, -8), 40, Color("#dba8ec"), 0.5, 2)
	Fx.text(fx, player.global_position, "获得 " + Relics.display_name(id), UiTheme.GOLD)


func _use_shrine(shrine: Interactable) -> void:
	if not Run.is_hurt():
		hud.toast("你的灯火正旺，留着以后再来吧", UiTheme.MIST)
		return
	Run.heal(SHRINE_HEAL)
	Sound.play("heal")
	shrine.spend(SpriteLib.region("props", "shrine_out"), 0.15)
	Fx.text(fx, player.global_position, "+%d 生命" % SHRINE_HEAL, UiTheme.GOLD)
	Fx.burst(fx, player.global_position + Vector2(0, -8), UiTheme.GOLD, 16, 70, 0.6, 2.0)


func _descend() -> void:
	if director.in_fight():
		return
	stairs.enabled = false
	Sound.play("stairs")
	game.descend()


# ------------------------------------------------------------------ bosses
func _start_boss(room: DungeonRoom) -> void:
	var pos := NavGrid.cell_center(Vector2i(room.center.x, room.rect.position.y + 5))
	boss = spawn_enemy(boss_kind, pos, depth) as Boss
	boss.defeated.connect(_on_boss_defeated)
	hud.show_boss(boss)
	Sound.music("boss", 0.5)
	Sound.play("boss_roar")
	Juice.shake(0.6)
	camera.focus_override = pos + Vector2(0, -16)
	after(BOSS_INTRO_TIME, func() -> void: camera.focus_override = Vector2.INF)


func _on_boss_defeated(fallen: Boss) -> void:
	var pos := fallen.global_position + fallen.hit_offset
	boss = null
	hud.hide_boss()
	clear_enemy_bullets(pos, 2000)
	director.cancel_pending()
	for e in enemies.duplicate():
		if not e.dead and e != fallen:
			e.die()
	Sound.stop_music(0.5)
	Juice.hitstop(0.25, 0.1)
	Juice.shake(1.0)
	for k in 6:
		var off := Vector2.from_angle(k * 1.1) * (10 + k * 6)
		Fx.anim(fx, "boom", pos + off, "pop", 22, 1.2 + k * 0.1)
	Fx.light_flash(fx, pos, Color(1, 0.85, 0.6), 3.0, 3.0, 1.2)
	Sound.play("explode")
	if Depths.is_final(depth):
		hud.toast("熄灯者熄灭了……", UiTheme.GOLD)
		after(VICTORY_DELAY, game.finish_run.bind(true))
		return
	drop_embers(pos, BOSS_EMBERS)
	if Run.is_hurt():
		drop_oil(pos + Vector2(10, 0))
	after(STAIRS_DELAY, _reveal_stairs)


func _reveal_stairs() -> void:
	director.finish_fight()
	_add_stairs(NavGrid.cell_center(gen.find_room(DungeonRoom.Type.BOSS).center))
	hud.toast("通往下一层的楼梯出现了", UiTheme.GOLD)
	Sound.music(biome, 2.0)


## The Snuffer's light-eating attack: the lantern and the room dim for a while.
func snuff_light(duration: float) -> void:
	_snuff_t = duration
	var tw := create_tween().set_parallel(true)
	tw.tween_property(player, "light_mult", SNUFF_LIGHT, 0.6)
	tw.tween_property(darkness, "color", ambient * SNUFF_AMBIENT, 0.6)
	hud.toast("灯光被压暗了！", Color("#a466c4"))


func _restore_light() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(player, "light_mult", 1.0, 1.0)
	tw.tween_property(darkness, "color", ambient, 1.0)
