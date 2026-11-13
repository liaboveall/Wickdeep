class_name ActorGfx
extends RefCounted
## Parts every actor is assembled from: the round physics body, the white hit-flash material and
## a soft ground shadow.

const SHADOW_COLOR := Color(0.04, 0.02, 0.07, 0.45)

static var _shadow_textures := {}


## Set up a CharacterBody2D as a small circle at the actor's feet that only collides with walls.
static func setup_body(body: CharacterBody2D, layer: int, radius := 4.5) -> void:
	body.collision_layer = layer
	body.collision_mask = PhysicsLayers.WORLD
	body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	shape.position = Vector2(0, -3)
	body.add_child(shape)


## Material whose `flash` parameter (0..1) whites the sprite out.
static func flash_material() -> ShaderMaterial:
	return Fx.shader_material("flash")


static func shadow(width: int) -> Sprite2D:
	if not _shadow_textures.has(width):
		var height := maxi(3, width / 3)
		var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
		for y in height:
			for x in width:
				var dx := (x + 0.5 - width / 2.0) / (width / 2.0)
				var dy := (y + 0.5 - height / 2.0) / (height / 2.0)
				if dx * dx + dy * dy <= 1.0:
					img.set_pixel(x, y, SHADOW_COLOR)
		_shadow_textures[width] = ImageTexture.create_from_image(img)
	var s := Sprite2D.new()
	s.texture = _shadow_textures[width]
	s.z_index = -1
	return s
