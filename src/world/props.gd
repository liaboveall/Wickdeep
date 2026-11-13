class_name Props
extends RefCounted
## Builders for the things rooms are furnished with. They only assemble nodes; what using one
## does is decided by whoever places it (Level, Camp).

const ALTAR_GLOW := Color(0.75, 0.5, 1.0)
const SHRINE_GLOW := Color(1.0, 0.8, 0.5)
const STAIRS_GLOW := Color(0.6, 0.8, 1.0)


## A single frame from the props sheet as a sprite.
static func sprite(prop: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SpriteLib.region("props", prop)
	return s


static func altar() -> Interactable:
	var it := _standing("altar", Interactable.Kind.ALTAR, "查看祭坛")
	it.light = Lights.make(ALTAR_GLOW, 70.0, 0.9)
	it.light.position = Vector2(0, -8)
	it.add_child(it.light)
	return it


static func shrine() -> Interactable:
	var it := _standing("shrine", Interactable.Kind.SHRINE, "在圣烛台前祈祷")
	it.light = Lights.flicker(SHRINE_GLOW, 80.0)
	it.light.position = Vector2(0, -10)
	it.add_child(it.light)
	return it


## The interaction spot of a staircase (the steps themselves are a floor decal, see stairs_decal).
static func stairs(prompt: String) -> Interactable:
	var it := Interactable.new()
	it.kind = Interactable.Kind.STAIRS
	it.prompt = prompt
	it.radius = 24.0
	return it


static func stairs_decal(biome: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SpriteLib.tile_region(biome, TileFactory.STAIRS, Vector2i(2, 2))
	return s


static func breakable(prop: String) -> Breakable:
	var b := Breakable.new()
	b.prop = prop
	return b


static func _standing(prop: String, kind: Interactable.Kind, prompt: String) -> Interactable:
	var it := Interactable.new()
	it.kind = kind
	it.prompt = prompt
	it.sprite = sprite(prop)
	it.sprite.position = Vector2(0, -8)
	it.add_child(it.sprite)
	return it
