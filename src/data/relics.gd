class_name Relics
extends RefCounted
## Relic and potion catalogue. Each relic carries its own effect table (see PlayerStats.apply),
## so adding a relic means adding one entry here plus an icon in tools/assetgen.

const RARITY_WEIGHT := {"common": 60, "rare": 30, "legendary": 8, "cursed": 6}
const RARITY_PRICE := {"common": 45, "rare": 75, "legendary": 120, "cursed": 30}
const RARITY_NAME := {"common": "普通", "rare": "稀有", "legendary": "传说", "cursed": "诅咒"}
const RARITY_COLOR := {
	"common": Color("#b9aa8c"), "rare": Color("#5797ad"),
	"legendary": Color("#f5b84c"), "cursed": Color("#d8503f"),
}

## max = how many copies can be owned (stacking). add / mul / set = effect on PlayerStats.
const DEFS := {
	"twin_wick": {"name": "双芯", "rarity": "rare", "max": 3, "desc": "多射出 1 发余烬弹，呈扇形散开。",
		"add": {"projectiles": 1}},
	"keen_spark": {"name": "锋利火星", "rarity": "common", "max": 4, "desc": "伤害 +25%。",
		"add": {"damage_bonus": 0.25}},
	"quickburn": {"name": "急燃", "rarity": "common", "max": 4, "desc": "射速 +20%。",
		"add": {"rate_bonus": 0.20}},
	"pierce": {"name": "穿透之光", "rarity": "common", "max": 3, "desc": "子弹多穿透 1 个敌人。",
		"add": {"pierce": 1}},
	"ricochet": {"name": "回弹", "rarity": "common", "max": 3, "desc": "子弹碰墙后反弹 1 次。",
		"add": {"bounces": 1}},
	"searing": {"name": "灼烧", "rarity": "common", "max": 3, "desc": "命中时 20% 几率点燃敌人，持续造成伤害。",
		"add": {"burn_chance": 0.20}},
	"seeker": {"name": "寻焰", "rarity": "rare", "max": 2, "desc": "子弹会追踪附近的敌人。",
		"add": {"homing": 3.2}},
	"long_flame": {"name": "远焰", "rarity": "common", "max": 3, "desc": "射程 +40%，弹速 +20%。",
		"mul": {"shot_range": 1.4, "shot_speed": 1.2}},
	"glass_shade": {"name": "琉璃灯罩", "rarity": "rare", "max": 1, "desc": "每个房间抵挡第一次伤害。",
		"set": {"shade": true}},
	"moth_heart": {"name": "飞蛾之心", "rarity": "rare", "max": 1, "desc": "每击败 25 个敌人，恢复 1 点生命。",
		"set": {"moth": true}},
	"light_feet": {"name": "轻足", "rarity": "common", "max": 3, "desc": "移动速度 +15%。",
		"mul": {"move_speed": 1.15}},
	"shadow_step": {"name": "影步", "rarity": "rare", "max": 1, "desc": "冲刺冷却 -30%，冲刺穿过敌人时造成 20 点伤害。",
		"mul": {"dash_cooldown": 0.7}, "set": {"dash_damage": 20.0}},
	"ember_magnet": {"name": "余烬磁石", "rarity": "common", "max": 2, "desc": "拾取范围翻倍，余烬掉落 +20%。",
		"mul": {"pickup_radius": 2.0}, "add": {"ember_mult": 0.2}},
	"combustion": {"name": "爆燃者", "rarity": "rare", "max": 2, "desc": "敌人死亡时爆炸，对周围造成 15 点伤害。",
		"add": {"explode_on_kill": 15.0}},
	"motes": {"name": "环绕火灵", "rarity": "rare", "max": 3, "desc": "2 团火灵环绕你，灼伤接触的敌人。",
		"add": {"mote_stacks": 1}},
	"lucky_spark": {"name": "幸运火星", "rarity": "common", "max": 3, "desc": "15% 几率暴击，造成双倍伤害。",
		"add": {"crit_chance": 0.15}},
	"thick_wax": {"name": "厚蜡", "rarity": "common", "max": 4, "desc": "生命上限 +2，并恢复 2 点生命。",
		"add": {"max_hp_bonus": 2}},
	"calm_flame": {"name": "静焰", "rarity": "common", "max": 3, "desc": "爆燃充能速度 +50%。",
		"add": {"flare_rate": 0.5}},
	"shatter": {"name": "碎晶", "rarity": "legendary", "max": 1, "desc": "子弹命中后分裂成 3 片碎晶。",
		"set": {"shatter": true}},
	"slow_burn": {"name": "缓燃沙漏", "rarity": "rare", "max": 2, "desc": "敌方子弹速度 -15%。",
		"mul": {"enemy_bullet_speed": 0.85}},
	"greedy_lamp": {"name": "贪婪之灯", "rarity": "cursed", "max": 1, "desc": "余烬掉落 +60%，但生命上限 -2。",
		"add": {"ember_mult": 0.6, "max_hp_bonus": -2}},
	"wildfire": {"name": "野火", "rarity": "rare", "max": 2, "desc": "射速 +45%，但子弹更散。",
		"add": {"rate_bonus": 0.45, "inaccuracy": 7.0}},
	"warden_bell": {"name": "守夜铃", "rarity": "rare", "max": 1, "desc": "受到伤害时，自动释放一次免费爆燃。",
		"set": {"bell": true}},
	"second_wick": {"name": "续芯", "rarity": "legendary", "max": 1, "desc": "死亡时复燃一次，恢复 4 点生命。",
		"set": {"revive": true}},
	"molten_core": {"name": "熔核", "rarity": "legendary", "max": 1, "desc": "子弹更大，伤害 +60%，射速 -15%。",
		"mul": {"damage_mult": 1.6, "rate_mult": 0.85}, "set": {"bolt_scale": 1.6}},
}

## heal = hit points restored when bought (anything above the maximum is ignored).
const POTIONS := {
	"oil": {"name": "灯油", "price": 25, "desc": "恢复 2 点生命。", "heal": 2},
	"big_oil": {"name": "满瓶灯油", "price": 55, "desc": "恢复全部生命。", "heal": 999},
}


static func compute(relic_ids: Array) -> PlayerStats:
	var stats := PlayerStats.new()
	for id in relic_ids:
		if DEFS.has(id):
			stats.apply(DEFS[id])
	stats.resolve()
	return stats


static func is_potion(id: String) -> bool:
	return POTIONS.has(id)


static func rarity(id: String) -> String:
	return DEFS[id].rarity


static func count(relic_ids: Array, id: String) -> int:
	return relic_ids.count(id)


## Pick `n` distinct relics the player can still take, weighted by rarity.
static func roll(rng: RandomNumberGenerator, owned: Array, n: int, exclude: Array = []) -> Array[String]:
	var pool: Array[String] = []
	for id: String in DEFS:
		if id in exclude or count(owned, id) >= int(DEFS[id].max):
			continue
		pool.append(id)
	var out: Array[String] = []
	while out.size() < n and not pool.is_empty():
		var total := 0
		for id in pool:
			total += int(RARITY_WEIGHT[DEFS[id].rarity])
		var r := rng.randi_range(0, total - 1)
		for id in pool:
			r -= int(RARITY_WEIGHT[DEFS[id].rarity])
			if r < 0:
				out.append(id)
				pool.erase(id)
				break
	return out


## Price before depth mark-up and haggling (see Shop.price).
static func base_price(id: String) -> int:
	if is_potion(id):
		return int(POTIONS[id].price)
	return int(RARITY_PRICE[DEFS[id].rarity])


static func display_name(id: String) -> String:
	return POTIONS[id].name if is_potion(id) else DEFS[id].name


static func description(id: String) -> String:
	return POTIONS[id].desc if is_potion(id) else DEFS[id].desc


## "双芯、灼烧" for prompts; "无" when the list is empty.
static func names(ids: Array) -> String:
	if ids.is_empty():
		return "无"
	var out := PackedStringArray()
	for id in ids:
		out.append(display_name(id))
	return "、".join(out)


## Owned relics collapsed to [[id, copies], ...] in pick-up order, for icon rows and lists.
static func tally(ids: Array) -> Array:
	var order: Array = []
	var index := {}
	for id in ids:
		if index.has(id):
			order[index[id]][1] += 1
		else:
			index[id] = order.size()
			order.append([id, 1])
	return order
