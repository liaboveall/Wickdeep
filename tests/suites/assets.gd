extends "res://tests/test_suite.gd"
## The generated assets the code refers to by name are all there.

const SHEETS := ["player", "lantern", "bolt", "shard", "arrow", "wax", "ember", "oil", "torch", "campfire",
	"wick", "granny", "portraits", "props", "icons", "hud_flame", "dust", "puff", "spark", "boom",
	"orb_green", "orb_red", "orb_violet"]
const PROPS := ["altar", "altar_used", "shrine", "shrine_out", "pot", "pot_broken", "barrel", "skulls",
	"stall", "sign", "bedroll"]
const UI_TEXTURES := ["panel", "btn", "btn_hover", "btn_press", "btn_disabled", "bubble", "crosshair",
	"ember_icon", "key_e", "key_q", "logo", "frame_common", "frame_rare", "frame_legendary", "frame_cursed"]
const SOUNDS := ["shoot", "shoot_heavy", "hit", "crit", "burn", "enemy_die", "enemy_shoot", "arrow",
	"player_hurt", "player_die", "dash", "flare", "deny", "footstep", "pickup", "heal", "relic", "coin",
	"shield_break", "door_open", "door_close", "spawn", "stairs", "explode", "boss_roar", "boss_slam",
	"slime_hop", "knight_charge", "stun", "talk_wick", "talk_granny", "ui_select", "ui_move", "ui_back"]
const LOOPING_MUSIC := ["camp", "moss", "ash", "sanctum", "boss"]
const STINGS := ["victory", "death"]
const SHADERS := ["flash", "vignette", "title_backdrop"]


func test_sprite_sheets() -> void:
	for sheet: String in SHEETS:
		check(SpriteLib.manifest().has(sheet), "sprite sheet in manifest: " + sheet)
		check(SpriteLib.texture(sheet) != null, "sprite sheet loads: " + sheet)
	for prop: String in PROPS:
		check(SpriteLib.manifest().props.anims.has(prop), "prop: " + prop)
	for portrait: String in ["wick", "granny"]:
		check(SpriteLib.manifest().portraits.anims.has(portrait), "portrait: " + portrait)
	for fill: String in ["full", "half", "empty"]:
		check(SpriteLib.manifest().hud_flame.anims.has(fill), "health flame: " + fill)


func test_biome_tiles() -> void:
	for biome: String in Depths.BIOMES:
		check(SpriteLib.texture("tiles_" + biome) != null, "tile atlas: " + biome)
		var tiles := TileFactory.tileset(biome)
		check(tiles != null and tiles.get_source_count() == 1, "tile set builds: " + biome)
	for depth in range(1, Depths.FINAL + 1):
		check(Depths.BIOMES.has(Depths.biome(depth)), "depth %d uses a known biome" % depth)


func test_ui_textures_and_fonts() -> void:
	for texture: String in UI_TEXTURES:
		check(ResourceLoader.exists("res://assets/sprites/ui/%s.png" % texture), "ui texture: " + texture)
	check(UiTheme.pixel_font(true) != null and UiTheme.pixel_font(false) != null, "pixel fonts load")
	check(UiTheme.theme() != null, "theme builds")


func test_sounds() -> void:
	for sound: String in SOUNDS:
		check(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % sound), "sfx exists: " + sound)


func test_music_loops() -> void:
	for track: String in LOOPING_MUSIC:
		var wav: AudioStreamWAV = load("res://assets/audio/music/%s.wav" % track)
		check(wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music loops: " + track)
		if wav:
			var frames := int(wav.get_length() * wav.mix_rate)
			check(wav.loop_end == -1 or (wav.loop_end > frames * 0.98 and wav.loop_end <= frames),
				"loop end covers %s (%d of %d)" % [track, wav.loop_end, frames])
	for track: String in STINGS:
		check(ResourceLoader.exists("res://assets/audio/music/%s.wav" % track), "sting exists: " + track)
	for biome: String in Depths.BIOMES:
		check(biome in LOOPING_MUSIC, "every biome has a music track: " + biome)


func test_shaders() -> void:
	for shader: String in SHADERS:
		var material := Fx.shader_material(shader)
		check(material != null and material.shader != null, "shader loads: " + shader)
