extends Node
## Registers the input map in code (keyboard + mouse + gamepad) and tracks which
## device the player used last, so aiming can follow either the mouse or the right stick.

signal device_changed(using_gamepad: bool)

const DEADZONE := 0.25
const STICK_AIM_THRESHOLD := 0.35

const KEYS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"shoot": [],
	"dash": [KEY_SPACE, KEY_SHIFT],
	"flare": [KEY_Q],
	"interact": [KEY_E, KEY_F],
	"pause": [KEY_ESCAPE, KEY_P],
	"map": [KEY_TAB],
	"ui_confirm_alt": [KEY_ENTER],
}

const MOUSE_BUTTONS := {
	"shoot": [MOUSE_BUTTON_LEFT],
	"dash": [MOUSE_BUTTON_RIGHT],
}

const JOY_BUTTONS := {
	"move_up": [JOY_BUTTON_DPAD_UP],
	"move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_left": [JOY_BUTTON_DPAD_LEFT],
	"move_right": [JOY_BUTTON_DPAD_RIGHT],
	"dash": [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER],
	"flare": [JOY_BUTTON_RIGHT_SHOULDER],
	"interact": [JOY_BUTTON_X],
	"pause": [JOY_BUTTON_START],
	"map": [JOY_BUTTON_BACK],
}

## action -> [axis, direction]
const JOY_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"shoot": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}

var using_gamepad := false
var _stick_aim := Vector2.RIGHT


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		for key: Key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action: String in MOUSE_BUTTONS:
		for button: MouseButton in MOUSE_BUTTONS[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
	for action: String in JOY_BUTTONS:
		for button: JoyButton in JOY_BUTTONS[action]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
	for action: String in JOY_AXES:
		var event := InputEventJoypadMotion.new()
		event.axis = JOY_AXES[action][0]
		event.axis_value = JOY_AXES[action][1]
		InputMap.action_add_event(action, event)


func _input(event: InputEvent) -> void:
	var from_pad: bool = event is InputEventJoypadButton \
		or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4)
	var from_desk: bool = event is InputEventKey or event is InputEventMouseButton \
		or (event is InputEventMouseMotion and event.relative.length() > 2.0)
	if from_pad and not using_gamepad:
		using_gamepad = true
		device_changed.emit(true)
	elif from_desk and using_gamepad:
		using_gamepad = false
		device_changed.emit(false)


func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.2)


## Right-stick aim; keeps the last direction when the stick is centred.
func stick_aim() -> Vector2:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > STICK_AIM_THRESHOLD:
		_stick_aim = stick.normalized()
	return _stick_aim
