class_name SpriteLib
extends RefCounted
## Loads the generated sprite sheets described by assets/sprites/manifest.json.

const DIR := "res://assets/sprites/"

static var _manifest := {}
static var _textures := {}
static var _frames := {}
static var _regions := {}


static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var res = load(DIR + "manifest.json")
		if res is JSON:
			_manifest = res.data
		else:
			var f := FileAccess.open(DIR + "manifest.json", FileAccess.READ)
			_manifest = JSON.parse_string(f.get_as_text())
	return _manifest


static func texture(sheet: String) -> Texture2D:
	if not _textures.has(sheet):
		var m: Dictionary = manifest().get(sheet, {})
		var file: String = m.get("file", sheet + ".png")
		_textures[sheet] = load(DIR + file)
	return _textures[sheet]


static func ui(name: String) -> Texture2D:
	var key := "ui/" + name
	if not _textures.has(key):
		_textures[key] = load(DIR + "ui/" + name + ".png")
	return _textures[key]


## SpriteFrames with one animation per manifest row.
static func frames(sheet: String) -> SpriteFrames:
	if _frames.has(sheet):
		return _frames[sheet]
	var m: Dictionary = manifest()[sheet]
	var tex := texture(sheet)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var fw: int = m.w
	var fh: int = m.h
	for anim in m.anims:
		var a: Dictionary = m.anims[anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(a.fps))
		sf.set_animation_loop(anim, bool(a.loop))
		for i in int(a.frames):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, int(a.row) * fh, fw, fh)
			sf.add_frame(anim, at)
	_frames[sheet] = sf
	return sf


## Single frame as a texture (icons, props).
static func region(sheet: String, anim: String, frame := 0) -> AtlasTexture:
	var key := "%s/%s/%d" % [sheet, anim, frame]
	if _regions.has(key):
		return _regions[key]
	var m: Dictionary = manifest()[sheet]
	var a: Dictionary = m.anims[anim]
	var at := AtlasTexture.new()
	at.atlas = texture(sheet)
	at.region = Rect2(frame * int(m.w), int(a.row) * int(m.h), m.w, m.h)
	_regions[key] = at
	return at


static func icon(id: String) -> AtlasTexture:
	return region("icons", id)


static func tile_region(biome: String, atlas: Vector2i, size := Vector2i(1, 1)) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = texture("tiles_" + biome)
	at.region = Rect2(atlas.x * 16, atlas.y * 16, size.x * 16, size.y * 16)
	return at


static func make_sprite(sheet: String, anim := "") -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames(sheet)
	var first: String = anim if anim != "" else s.sprite_frames.get_animation_names()[0]
	s.play(first)
	return s
