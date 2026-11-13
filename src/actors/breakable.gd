class_name Breakable
extends Node2D
## A pot or barrel: shooting it drops a few embers, now and then a bottle of oil.

const OIL_CHANCE := 0.08
const EMBER_CHANCE := 0.7

var world: World
var radius := 6.0
var prop := "pot"
var broken := false
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Props.sprite(prop)
	_sprite.position = Vector2(0, -6)
	add_child(_sprite)


func smash() -> void:
	if broken:
		return
	broken = true
	world.props.erase(self)
	Sound.play("hit", -2.0, 0.7, 0.1)
	Fx.burst(world.fx, position + Vector2(0, -6), Color("#a8663a"), 8, 60, 0.4, 2.0, false)
	if prop == "pot":
		_sprite.texture = SpriteLib.region("props", "pot_broken")
	else:
		_sprite.visible = false
	var roll := randf()
	if roll < OIL_CHANCE and Run.is_hurt():
		world.drop_oil(position)
	elif roll < EMBER_CHANCE:
		world.drop_embers(position, randi_range(1, 2))
