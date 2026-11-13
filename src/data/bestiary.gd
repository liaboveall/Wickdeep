class_name Bestiary
extends RefCounted
## Enemy catalogue: display names, scripts, spawn costs, per-depth pools and wave composition.
## The numbers that shape how an enemy fights live in its own script under actors/enemies/.

const DIR := "res://src/actors/enemies/"

## cost = budget points a room pays to spawn one (0 = never rolled, only summoned).
const ENTRIES := {
	"slime": {"name": "灰泥史莱姆", "cost": 1},
	"bat": {"name": "煤灰蝙蝠", "cost": 1},
	"archer": {"name": "骨弓手", "cost": 2},
	"pod": {"name": "孢子囊", "cost": 2},
	"wisp": {"name": "幽火术士", "cost": 3},
	"knight": {"name": "墓甲骑士", "cost": 4},
	"shade": {"name": "小影", "cost": 0},
	"matron": {"name": "苔母", "cost": 0, "boss_title": "苔石回廊的主人"},
	"snuffer": {"name": "熄灯者", "cost": 0, "boss_title": "吞噬光明者"},
}

## Which enemies appear at each depth, with relative weights.
const POOLS := {
	1: {"slime": 5, "bat": 3, "archer": 2, "pod": 1},
	2: {"slime": 4, "bat": 3, "archer": 3, "pod": 2, "wisp": 1},
	3: {"slime": 2, "bat": 3, "archer": 3, "pod": 2, "wisp": 2, "knight": 2},
	4: {"slime": 2, "bat": 2, "archer": 3, "pod": 2, "wisp": 3, "knight": 3},
	5: {"bat": 2, "archer": 3, "wisp": 3, "knight": 3},
}

const HP_GROWTH_PER_DEPTH := 0.22
const MAX_WAVE_SIZE := 9
## Rooms with a bigger budget than this split it over two waves.
const SINGLE_WAVE_BUDGET := 7


static func has(kind: String) -> bool:
	return ENTRIES.has(kind)


static func script_path(kind: String) -> String:
	return DIR + kind + ".gd"


static func create(kind: String) -> Enemy:
	var enemy: Enemy = load(script_path(kind)).new()
	enemy.kind = kind
	return enemy


static func display_name(kind: String, unknown := "未知") -> String:
	return ENTRIES[kind].name if ENTRIES.has(kind) else unknown


static func boss_title(kind: String) -> String:
	return ENTRIES.get(kind, {}).get("boss_title", "")


static func cost(kind: String) -> int:
	return ENTRIES[kind].cost


## Ordinary enemies get tougher with depth; bosses have hand-tuned health.
static func hp_scale(depth: int) -> float:
	return 1.0 + HP_GROWTH_PER_DEPTH * (depth - 1)


## How many budget points a combat room of `area` tiles gets at this depth.
static func room_budget(depth: int, area: int) -> int:
	return 3 + depth * 2 + maxi(0, depth - 2) + area / 70


## Spend a room's budget on one or two waves of enemy kinds.
static func compose(rng: RandomNumberGenerator, depth: int, area: int) -> Array:
	var budget := room_budget(depth, area)
	var pool: Dictionary = POOLS.get(depth, POOLS[4])
	var wave_budgets := [budget]
	if budget > SINGLE_WAVE_BUDGET:
		var first := int(ceil(budget * 0.55))
		wave_budgets = [first, budget - first]
	var waves := []
	for wave_budget: int in wave_budgets:
		var left := wave_budget
		var wave: Array[String] = []
		var attempts := 0
		while left > 0 and wave.size() < MAX_WAVE_SIZE and attempts < 50:
			attempts += 1
			var kind := _pick(rng, pool)
			# nearly out of budget: fall back to something cheap instead of rolling forever
			if cost(kind) > left and left < 2:
				kind = "slime" if pool.has("slime") else "bat"
			if cost(kind) > left:
				continue
			wave.append(kind)
			left -= cost(kind)
		if not wave.is_empty():
			waves.append(wave)
	return waves


static func _pick(rng: RandomNumberGenerator, pool: Dictionary) -> String:
	var total := 0
	for kind in pool:
		total += pool[kind]
	var r := rng.randi_range(0, total - 1)
	for kind in pool:
		r -= pool[kind]
		if r < 0:
			return kind
	return pool.keys()[0]
