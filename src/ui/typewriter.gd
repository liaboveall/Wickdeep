class_name Typewriter
extends Node
## Reveals the text of a RichTextLabel character by character, with a talking blip.
## Add it as a child of whatever owns the label; it keeps running while the game is paused.

signal finished

var label: RichTextLabel
var chars_per_second := 60.0
var blip := "talk_wick"
var blip_volume := -10.0
var blip_pitch_var := 0.08
var blip_every := 3             # characters between blips
var _typing := false
var _shown := 0.0
var _since_blip := 0


func _init(target: RichTextLabel) -> void:
	label = target
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_typing() -> bool:
	return _typing


## Type out everything after the first `already_shown` characters.
func start(already_shown := 0) -> void:
	_shown = already_shown
	label.visible_characters = already_shown
	_typing = true


## Show the rest at once.
func skip() -> void:
	label.visible_characters = -1
	_typing = false


func _process(delta: float) -> void:
	if not _typing:
		return
	var before := int(_shown)
	_shown += delta * chars_per_second
	var total := label.get_total_character_count()
	if int(_shown) >= total:
		skip()
		finished.emit()
		return
	label.visible_characters = int(_shown)
	_since_blip += int(_shown) - before
	if _since_blip >= blip_every:
		_since_blip = 0
		Sound.play(blip, blip_volume, 1.0, blip_pitch_var)
