class_name DungeonRoom
extends RefCounted
## One room of a generated depth (layout only; what happens inside is tracked by RoomDirector).

enum Type { START, COMBAT, TREASURE, SHRINE, EXIT, BOSS }

const TYPE_NAMES := {
	Type.START: "start", Type.COMBAT: "combat", Type.TREASURE: "treasure",
	Type.SHRINE: "shrine", Type.EXIT: "exit", Type.BOSS: "boss",
}

var id := 0
var cell := Vector2i.ZERO        # position on the macro grid
var type := Type.COMBAT
var links: Array[int] = []       # ids of the rooms this one has a corridor to
var dist := 0                    # corridors between here and the start room
var center := Vector2i.ZERO      # in tiles
var rect := Rect2i()             # floor area in tiles
var doors: Array[Door] = []
var pattern := ""                # obstacle layout of a combat room ("" = not decided / none)


## A doorway into a corridor. Its cells can be barred while a fight is on.
class Door:
	var dir := Vector2i.ZERO     # which way the corridor leaves the room
	var cells: Array[Vector2i] = []
	var to := -1                 # id of the room at the other end


func _init(room_id := 0, grid_cell := Vector2i.ZERO, room_type := Type.COMBAT) -> void:
	id = room_id
	cell = grid_cell
	type = room_type


func type_name() -> String:
	return TYPE_NAMES[type]


## Rooms that lock their doors until everything inside is dead.
func has_fight() -> bool:
	return type == Type.COMBAT or type == Type.BOSS


func area() -> int:
	return rect.size.x * rect.size.y


func add_door(dir: Vector2i, cells: Array[Vector2i], to: int) -> void:
	var door := Door.new()
	door.dir = dir
	door.cells = cells
	door.to = to
	doors.append(door)


func door_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for door in doors:
		out.append_array(door.cells)
	return out
