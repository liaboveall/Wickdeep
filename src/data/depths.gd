class_name Depths
extends RefCounted
## The five floors of the abyss and the look of each biome, in one table.

const FINAL := 5

const TABLE := {
	1: {"biome": "moss", "name": "苔石回廊", "boss": ""},
	2: {"biome": "moss", "name": "苔石回廊", "boss": "matron"},
	3: {"biome": "ash", "name": "骨灰书库", "boss": ""},
	4: {"biome": "ash", "name": "骨灰书库", "boss": ""},
	5: {"biome": "sanctum", "name": "熄灭圣所", "boss": "snuffer"},
}

## ambient = CanvasModulate colour (how dark the unlit world is); dust = drifting particles.
const BIOMES := {
	"moss": {"ambient": Color(0.3, 0.3, 0.39), "dust": Color(0.66, 0.77, 0.42, 0.55)},
	"ash": {"ambient": Color(0.34, 0.28, 0.3), "dust": Color(0.9, 0.7, 0.45, 0.5)},
	"sanctum": {"ambient": Color(0.25, 0.23, 0.37), "dust": Color(0.75, 0.6, 1.0, 0.5)},
	"camp": {"ambient": Color(0.4, 0.34, 0.36), "dust": Color(1.0, 0.75, 0.45, 0.5)},
}

const NUMERALS := ["一", "二", "三", "四", "五"]


static func entry(depth: int) -> Dictionary:
	return TABLE[clampi(depth, 1, FINAL)]


static func biome(depth: int) -> String:
	return entry(depth).biome


## Kind of the boss guarding this depth's exit, or "" for an ordinary floor.
static func boss(depth: int) -> String:
	return entry(depth).boss


static func is_final(depth: int) -> bool:
	return depth >= FINAL


## "第三层 · 骨灰书库"
static func title(depth: int) -> String:
	return "第%s层 · %s" % [NUMERALS[clampi(depth, 1, FINAL) - 1], entry(depth).name]


static func ambient(biome_name: String) -> Color:
	return BIOMES.get(biome_name, BIOMES.moss).ambient


static func dust(biome_name: String) -> Color:
	return BIOMES.get(biome_name, BIOMES.moss).dust
