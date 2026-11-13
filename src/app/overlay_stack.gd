class_name OverlayStack
extends CanvasLayer
## The menus open on top of the game (pause, shop, settings, ...). The game is paused for as long
## as at least one is open; menus can stack (pause -> settings).

const LAYER := 50

var game: Game
var _open: Array[Overlay] = []


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_empty() -> bool:
	return _open.is_empty()


func top() -> Overlay:
	return _open.back() if not _open.is_empty() else null


func push(overlay: Overlay) -> Overlay:
	overlay.game = game
	add_child(overlay)
	_open.append(overlay)
	get_tree().paused = true
	return overlay


func pop(overlay: Overlay) -> void:
	_open.erase(overlay)
	overlay.queue_free()
	if _open.is_empty():
		get_tree().paused = false


## Close everything at once (when the screen underneath is replaced).
func clear() -> void:
	for overlay in _open:
		overlay.queue_free()
	_open.clear()
	get_tree().paused = false
