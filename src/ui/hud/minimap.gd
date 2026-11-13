class_name Minimap
extends Control
## Map of the current depth, drawn from the dungeon layout: the rooms the player has visited and
## the neighbours those lead to. Shown small in the corner, and large while the map key is held.

const BACKDROP := Color(0.05, 0.03, 0.08)
const CORRIDOR := Color("#524a6c")
const OUTLINE := Color("#120e18")
const ROOM_UNVISITED := Color("#383050")
const ROOM_VISITED := Color("#766d8e")
const ROOM_CLEARED := Color("#a49bb6")
const TREASURE := Color("#dba8ec")
## Marker drawn in the middle of special rooms.
const MARKERS := {
	DungeonRoom.Type.TREASURE: TREASURE,
	DungeonRoom.Type.SHRINE: UiTheme.TEAL,
	DungeonRoom.Type.EXIT: UiTheme.CREAM,
	DungeonRoom.Type.BOSS: UiTheme.RED,
}
const LEGEND := [["宝藏", TREASURE], ["圣烛台", UiTheme.TEAL], ["出口", UiTheme.CREAM],
	["首领", UiTheme.RED], ["你", UiTheme.GOLD]]

var hud: Hud
var scale_px := 0.25      # screen pixels per tile
var big := false          # full-screen version with a legend


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var level := hud.world as Level
	if level == null or level.director == null:
		return
	var rooms := level.gen.rooms
	var known := _known_rooms(level)   # room id -> visited (false = only seen from next door)
	if known.is_empty():
		return
	var origin := _draw_frame(level)
	for edge: Array in level.gen.edges:
		if known.has(edge[0]) and known.has(edge[1]) and (known[edge[0]] or known[edge[1]]):
			draw_line(Vector2(rooms[edge[0]].center) * scale_px + origin,
				Vector2(rooms[edge[1]].center) * scale_px + origin, CORRIDOR, maxf(1.0, scale_px * 2.0))
	var visible_area := Rect2(Vector2(-2, -2), size + Vector2(4, 4))
	for id: int in known:
		var room := rooms[id]
		var rect := Rect2(Vector2(room.rect.position) * scale_px + origin, Vector2(room.rect.size) * scale_px)
		if not big and not visible_area.intersects(rect):
			continue
		draw_rect(rect, _room_color(level, id, known[id]))
		draw_rect(rect, OUTLINE, false, 1.0)
		if MARKERS.has(room.type):
			var marker := maxf(2.0, scale_px * 6.0) * Vector2.ONE
			draw_rect(Rect2(rect.get_center() - marker / 2.0, marker), MARKERS[room.type])
	if is_instance_valid(hud.player):
		var at := hud.player.global_position / World.TILE * scale_px + origin
		draw_rect(Rect2(at - Vector2.ONE, Vector2(4, 4) if big else Vector2(2, 2)), UiTheme.CREAM)


func _known_rooms(level: Level) -> Dictionary:
	var known := {}
	for room in level.gen.rooms:
		if level.director.is_visited(room.id):
			known[room.id] = true
			for neighbour in room.links:
				known[neighbour] = known.get(neighbour, false)
	return known


func _room_color(level: Level, id: int, visited: bool) -> Color:
	if id == level.director.current:
		return UiTheme.GOLD
	if not visited:
		return ROOM_UNVISITED
	return ROOM_CLEARED if level.director.is_cleared(id) else ROOM_VISITED


## Draw the backdrop (and, on the big map, the legend); returns where tile (0, 0) goes.
func _draw_frame(level: Level) -> Vector2:
	if not big:
		draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), Color(BACKDROP, 0.6))
		# the small map stays centred on the room the player is in
		var here := level.gen.rooms[maxi(level.director.current, 0)].rect
		return size / 2.0 - Vector2(here.get_center()) * scale_px
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKDROP, 0.85))
	var x := 150.0
	var y := size.y - 14.0
	draw_string(UiTheme.font(), Vector2(x, y), Run.depth_title(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.GOLD)
	x += 120.0
	for entry: Array in LEGEND:
		var text: String = entry[0]
		draw_rect(Rect2(x, y - 8, 6, 6), entry[1])
		draw_string(UiTheme.font(), Vector2(x + 9, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.MIST)
		x += 22.0 + 12.0 * text.length()
	var span := Vector2(level.gen.w, level.gen.h) * scale_px
	return ((size - span) / 2.0 - Vector2(0, 8)).round()
