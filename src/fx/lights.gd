class_name Lights
extends RefCounted
## Shared light textures. The scene is rendered at 640x360, so lights come out naturally pixelated.

## The radial texture is 256px across, so texture_scale 1.0 lights a 128px radius.
const TEXTURE_RADIUS := 128.0

static var _radial: Texture2D


## Radial gradient with a smooth falloff.
static func radial() -> Texture2D:
	if _radial == null:
		# Fade the colour itself (not just alpha): Light2D adds texture RGB, so a white-with-alpha
		# texture would light the whole square evenly.
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 0.8, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1), Color(0.82, 0.82, 0.82), Color(0.42, 0.42, 0.42),
			Color(0.12, 0.12, 0.12), Color(0, 0, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 256
		t.height = 256
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_radial = t
	return _radial


static func make(color: Color, radius_px: float, energy := 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = radial()
	l.color = color
	l.energy = energy
	l.texture_scale = radius_px / TEXTURE_RADIUS
	return l


## A light that wavers like a flame (torches, fires, the player's lantern).
static func flicker(color: Color, radius_px: float, energy := 1.0, speed := 1.0) -> Flicker:
	var l := Flicker.new()
	l.texture = radial()
	l.color = color
	l.base_energy = energy
	l.base_scale = radius_px / TEXTURE_RADIUS
	l.speed = speed
	return l


class Flicker:
	extends PointLight2D
	var base_energy := 1.0
	var base_scale := 1.0
	var speed := 1.0
	var _t := 0.0

	func _ready() -> void:
		_t = randf() * 10.0

	func _process(delta: float) -> void:
		_t += delta * speed
		var n := sin(_t * 7.3) * 0.5 + sin(_t * 13.1 + 1.7) * 0.3 + sin(_t * 3.1) * 0.2
		energy = base_energy * (1.0 + n * 0.12)
		texture_scale = base_scale * (1.0 + n * 0.035)
