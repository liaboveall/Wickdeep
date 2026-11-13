class_name Overlay
extends Control
## Base for full-screen menus shown over the game (the tree is paused while one is open).
## Subclasses build their controls in _build(); to change `dim` or `closable`, set them in _init().

signal closed

const FADE_IN := 0.15

var game: Game
var closable := true      # Esc / pause closes it
var dim := 0.6            # how dark the game behind gets


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.02, 0.07, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN)


func _build() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if closable and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		Sound.play("ui_back")
		close()


func close() -> void:
	closed.emit()
	if game:
		game.overlays.pop(self)
	else:
		queue_free()


func panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	return p


## Add `node` in the middle of the screen.
func add_centered(node: Control) -> void:
	add_child(Ui.fill_parent(Ui.center(node)))
