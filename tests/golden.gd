extends RefCounted
## Characterization ("golden") data: everything the game computes deterministically, in one
## dictionary, so a refactor can be checked against the numbers the code produced before it.
##
## baseline.json was first written by the pre-refactor code. build() must keep producing the same
## values in the same shape; tests/suites/golden.gd compares the two section by section.

const PATH := "res://tests/golden/baseline.json"
const DUNGEON_SEEDS := 40
const SEED_STEP := 7919

## Stat names as they appear in the baseline -> PlayerStats property.
const STAT_KEYS := {
	"damage": "damage", "fire_interval": "fire_interval", "shot_speed": "shot_speed", "range": "shot_range",
	"projectiles": "projectiles", "spread": "spread", "inaccuracy": "inaccuracy", "pierce": "pierce",
	"bounces": "bounces", "homing": "homing", "crit_chance": "crit_chance", "burn_chance": "burn_chance",
	"shatter": "shatter", "bolt_scale": "bolt_scale", "move_speed": "move_speed",
	"dash_cooldown": "dash_cooldown", "dash_damage": "dash_damage", "pickup_radius": "pickup_radius",
	"ember_mult": "ember_mult", "flare_rate": "flare_rate", "explode_on_kill": "explode_on_kill",
	"motes": "motes", "shade": "shade", "moth": "moth", "bell": "bell", "revive": "revive",
	"enemy_bullet_speed": "enemy_bullet_speed", "max_hp_bonus": "max_hp_bonus",
}


static func build() -> Dictionary:
	return {
		"dungeon": _dungeons(), "stats": _stats(), "waves": _waves(), "rolls": _rolls(),
		"clamp": _clamps(), "wrap": _wraps(), "clean": _cleans(), "times": _times(),
		"prices": _prices(), "titles": _titles(), "biomes": _biomes(),
	}


static func load_baseline() -> Dictionary:
	return JsonFile.read(PATH)


static func write() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(build(), "\t", true, true))


## The same data after a trip through JSON, i.e. with the types the baseline file has.
static func as_json(data: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(data, "", true, true))


## Paths at which `actual` differs from `expected` (numbers compared approximately).
static func diff(actual: Variant, expected: Variant) -> Array:
	var out := []
	_diff(actual, expected, "", out)
	return out


static func _diff(actual: Variant, expected: Variant, path: String, out: Array) -> void:
	if out.size() >= 10:
		return
	if actual is Dictionary and expected is Dictionary:
		for key: Variant in expected:
			if not actual.has(key):
				out.append("%s/%s missing" % [path, key])
			else:
				_diff(actual[key], expected[key], "%s/%s" % [path, key], out)
		for key: Variant in actual:
			if not expected.has(key):
				out.append("%s/%s unexpected" % [path, key])
	elif actual is Array and expected is Array:
		if actual.size() != expected.size():
			out.append("%s: %d items, expected %d" % [path, actual.size(), expected.size()])
		else:
			for i in actual.size():
				_diff(actual[i], expected[i], "%s[%d]" % [path, i], out)
	elif (actual is float or actual is int) and (expected is float or expected is int):
		if not is_equal_approx(float(actual), float(expected)):
			out.append("%s: %s, expected %s" % [path, actual, expected])
	elif typeof(actual) != typeof(expected) or actual != expected:
		out.append("%s: %s, expected %s" % [path, actual, expected])


# ------------------------------------------------------------------ sections
## One hash per generated layout, covering the grid, the room map and every room's fields.
static func _dungeons() -> Dictionary:
	var out := {}
	for depth in range(1, Depths.FINAL + 1):
		for s in DUNGEON_SEEDS:
			var gen := DungeonGen.new()
			gen.generate(s * SEED_STEP + depth, depth, Depths.boss(depth))
			out["d%d_s%d" % [depth, s]] = fingerprint(gen)
	return out


static func fingerprint(gen: DungeonGen) -> String:
	var parts := PackedStringArray()
	parts.append("%d,%d" % [gen.w, gen.h])
	for room in gen.rooms:
		var links := PackedStringArray()
		for link in room.links:
			links.append(str(link))
		var doors := PackedStringArray()
		for door in room.doors:
			var cells := PackedStringArray()
			for c in door.cells:
				cells.append("%d:%d" % [c.x, c.y])
			doors.append("%d:%d>%d[%s]" % [door.dir.x, door.dir.y, door.to, ",".join(cells)])
		parts.append("%d|%s|%d,%d|%d|%d,%d|%d,%d,%d,%d|%s|%s|%s" % [room.id, room.type_name(), room.cell.x,
			room.cell.y, room.dist, room.center.x, room.center.y, room.rect.position.x, room.rect.position.y,
			room.rect.size.x, room.rect.size.y, room.pattern, ",".join(links), ";".join(doors)])
	for edge: Array in gen.edges:
		parts.append("e%d-%d" % [edge[0], edge[1]])
	parts.append(gen.grid.hex_encode())
	var room_map := PackedStringArray()
	for id in gen.room_map:
		room_map.append(str(id))
	parts.append(",".join(room_map))
	return "\n".join(parts).sha256_text()


## Stats for every relic at every stack size, plus everything maxed at once.
static func _stats() -> Dictionary:
	var out := {"BASE": stats_dict(Relics.compute([]))}
	var everything := []
	for id: String in Relics.DEFS:
		var owned := []
		for n in range(1, int(Relics.DEFS[id].max) + 1):
			owned.append(id)
			everything.append(id)
			out["%s*%d" % [id, n]] = stats_dict(Relics.compute(owned))
	out["ALL"] = stats_dict(Relics.compute(everything))
	return out


static func stats_dict(stats: PlayerStats) -> Dictionary:
	var out := {}
	for key: String in STAT_KEYS:
		out[key] = stats.get(STAT_KEYS[key])
	return out


static func _waves() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var out := []
	for depth in range(1, Depths.FINAL + 1):
		for area: int in [150, 200, 260, 320, 375]:
			for k in 4:
				out.append(Bestiary.compose(rng, depth, area))
	return out


static func _rolls() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var out := []
	for k in 30:
		out.append(Relics.roll(rng, [], 3))
	for k in 10:
		out.append(Relics.roll(rng, ["twin_wick", "twin_wick", "twin_wick", "shatter", "glass_shade"], 3, ["pierce"]))
	return out


static func _clamps() -> Array:
	var out := []
	for current: float in [0.7, 0.72, 0.85, 1.0, 1.07, 1.28, 1.3]:
		for wanted: float in [0.0, 0.5, 0.69, 0.9, 0.95, 1.0, 1.04, 1.1, 1.5, 9.0]:
			out.append([current, wanted, Haggle.clamp_mult(current, wanted)])
	return out


static func _wraps() -> Array:
	var out := []
	for text: String in ["呼……你这灯油漏得比筛子还快，先坐下烤烤火。", "abc def ghi jkl mno pqr stu vwx yz 0123456789",
			"一根头发都没烧焦？我开始怀疑你偷偷练过了。", "短", "记住：骨弓手的红线一锁定，就往旁边冲刺。真的，别愣着！"]:
		for per_line: int in [6, 13, 20]:
			out.append([text, per_line, TextUtil.wrap(text, per_line)])
	return out


static func _cleans() -> Array:
	var out := []
	for text: String in ["  你好\n世界  ", "短句。", "长".repeat(120), "a\nb\nc"]:
		out.append([text, TextUtil.clean(text)])
	return out


static func _times() -> Array:
	var out := []
	for seconds: float in [0.0, 59.9, 60.0, 734.0, 3601.5]:
		out.append([seconds, TextUtil.clock(seconds)])
	return out


static func _prices() -> Dictionary:
	var out := {}
	for depth in range(1, Depths.FINAL + 1):
		for mult: float in [0.7, 0.85, 1.0, 1.13, 1.3]:
			for id: String in ["keen_spark", "twin_wick", "shatter", "greedy_lamp", "oil", "big_oil"]:
				out["d%d|%s|%.2f" % [depth, id, mult]] = Shop.price_at(id, depth, mult)
	return out


static func _titles() -> Dictionary:
	var out := {}
	for depth in range(1, Depths.FINAL + 1):
		out[str(depth)] = Depths.title(depth)
	return out


static func _biomes() -> Dictionary:
	var out := {}
	for depth in range(1, Depths.FINAL + 1):
		out[str(depth)] = Depths.biome(depth)
	return out
