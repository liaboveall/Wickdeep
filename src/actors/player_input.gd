class_name PlayerInput
extends RefCounted
## Where the player's commands come from. Human input reads the keyboard / mouse / gamepad;
## the test bot (src/dev/bot_input.gd) fills the same fields. A network input could too.

const STICK_AIM_DISTANCE := 70.0   # how far ahead the crosshair sits when aiming with a stick

var move := Vector2.ZERO
var aim := Vector2.RIGHT
var aim_point := Vector2.ZERO      # world position the crosshair is on
var shoot := false
var dash := false
var flare := false
var interact := false


## Called once per physics frame before the player acts.
func update(_player: Player, _delta: float) -> void:
	pass


func clear() -> void:
	move = Vector2.ZERO
	shoot = false
	dash = false
	flare = false
	interact = false


class Human:
	extends PlayerInput

	func update(player: Player, _delta: float) -> void:
		move = Inputs.move_vector()
		var origin := player.global_position + Player.AIM_ORIGIN
		if Inputs.using_gamepad:
			aim = Inputs.stick_aim()
			aim_point = origin + aim * STICK_AIM_DISTANCE
		else:
			aim_point = player.get_global_mouse_position()
			var d := aim_point - origin
			if d.length() > 2.0:
				aim = d.normalized()
		shoot = Input.is_action_pressed("shoot")
		dash = Input.is_action_just_pressed("dash")
		flare = Input.is_action_just_pressed("flare")
		interact = Input.is_action_just_pressed("interact")
