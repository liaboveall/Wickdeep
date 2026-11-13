class_name Interactable
extends Node2D
## Something the player can use with the interact key: altars, shrines, stairs, NPCs.
## Whoever creates one connects to `used`; the world decides which one is in reach.

signal used

## What it is, so code (the bot, for one) never has to guess from the prompt text.
enum Kind { OTHER, ALTAR, SHRINE, STAIRS, SHOP, WICK }

var kind := Kind.OTHER
var prompt := "交互"
var radius := 22.0
var enabled := true
var sprite: Sprite2D
var light: PointLight2D


func use() -> void:
	if enabled:
		used.emit()


## Used up: stop accepting interaction and switch to the spent look.
func spend(spent_texture: Texture2D = null, light_energy := -1.0) -> void:
	enabled = false
	if spent_texture and sprite:
		sprite.texture = spent_texture
	if light_energy >= 0.0 and light:
		if light is Lights.Flicker:
			(light as Lights.Flicker).base_energy = light_energy
		else:
			light.energy = light_energy
