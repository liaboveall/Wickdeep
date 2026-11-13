extends Node
## State of the current run: health, embers, relics, statistics. Single source of truth for the HUD.

signal changed

const BASE_MAX_HP := 6
const MIN_MAX_HP := 2
const FLARE_MAX := 100.0
const REVIVE_HP := 4
const MOTH_KILLS_PER_HEAL := 25

var active := false
var won := false
var seed_value := 0
var depth := 1
var hp := BASE_MAX_HP
var max_hp := BASE_MAX_HP
var embers := 0
var relics: Array = []
var flare := 0.0
var stats := PlayerStats.new()
var revive_used := false
var moth_counter := 0

# statistics
var kills := 0
var damage_dealt := 0.0
var damage_taken := 0
var rooms_cleared := 0
var time := 0.0
var killer := ""
var hurt_by := {}             # enemy kind -> damage taken this run
var history: Array = []       # summaries of finished depths, for Wick
var depth_log := DepthLog.new()   # the depth in progress

var camp := CampVisit.new()   # the current (or upcoming) stop at the camp
var wick_chat: Array = []     # this run's conversation with Wick, OpenAI message format


func new_run(seed_override := -1) -> void:
	active = true
	won = false
	seed_value = seed_override if seed_override >= 0 else randi() % 1000000
	depth = 1
	relics = []
	revive_used = false
	moth_counter = 0
	embers = 0
	flare = 0.0
	kills = 0
	damage_dealt = 0.0
	damage_taken = 0
	rooms_cleared = 0
	time = 0.0
	killer = ""
	hurt_by = {}
	history = []
	depth_log = DepthLog.new()
	wick_chat = []
	camp = _new_visit()
	recompute_stats()
	hp = max_hp
	SaveData.runs += 1
	SaveData.save_data()
	SaveData.clear_run()
	changed.emit()


func _new_visit() -> CampVisit:
	return CampVisit.new(Haggle.starting_mult(SaveData.granny_affinity))


func recompute_stats() -> void:
	stats = Relics.compute(relics)
	max_hp = maxi(MIN_MAX_HP, BASE_MAX_HP + stats.max_hp_bonus)
	hp = mini(hp, max_hp)


func biome() -> String:
	return Depths.biome(depth)


func depth_title() -> String:
	return Depths.title(depth)


# ------------------------------------------------------------------ resources
## Raising the health cap (thick wax) also fills the new wax in.
func add_relic(id: String) -> void:
	relics.append(id)
	SaveData.mark_seen(SaveData.seen_relics, id)
	var old_max := max_hp
	recompute_stats()
	if max_hp > old_max:
		hp = mini(max_hp, hp + (max_hp - old_max))
	changed.emit()


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	changed.emit()


func is_hurt() -> bool:
	return hp < max_hp


func add_embers(n: int) -> void:
	embers += n
	changed.emit()


func spend(n: int) -> bool:
	if embers < n:
		return false
	embers -= n
	changed.emit()
	return true


func add_flare(amount: float) -> void:
	flare = minf(FLARE_MAX, flare + amount * stats.flare_rate)
	changed.emit()


func flare_ready() -> bool:
	return flare >= FLARE_MAX


func spend_flare() -> void:
	flare = 0.0
	changed.emit()


# ------------------------------------------------------------------ combat bookkeeping
## Returns true if the player died from this hit (and no revive was left).
func take_damage(amount: int, source: String) -> bool:
	hp -= amount
	damage_taken += amount
	hurt_by[source] = int(hurt_by.get(source, 0)) + amount
	depth_log.add_damage(amount, source)
	if hp > 0:
		changed.emit()
		return false
	if stats.revive and not revive_used:
		revive_used = true
		hp = mini(REVIVE_HP, max_hp)
		changed.emit()
		return false
	hp = 0
	killer = source
	changed.emit()
	return true


func register_damage_dealt(amount: float) -> void:
	damage_dealt += amount
	add_flare(amount * 0.25)


func register_kill(kind: String) -> void:
	kills += 1
	depth_log.add_kill(kind)
	SaveData.total_kills += 1
	SaveData.mark_seen(SaveData.seen_enemies, kind)
	if stats.moth:
		moth_counter += 1
		if moth_counter >= MOTH_KILLS_PER_HEAL:
			moth_counter = 0
			heal(1)


# ------------------------------------------------------------------ run flow
## Called when the player takes the stairs: archive the depth summary and move on.
func finish_depth() -> void:
	history.append(depth_log.summary(depth, hp, max_hp))
	depth += 1
	SaveData.best_depth = maxi(SaveData.best_depth, depth)
	SaveData.save_data()
	depth_log = DepthLog.new()
	camp = _new_visit()
	changed.emit()


func end_run(victory: bool) -> void:
	active = false
	won = victory
	if victory:
		SaveData.wins += 1
	SaveData.clear_run()
	SaveData.save_data()


## Summary of the depth just finished, or {} on the first depth.
func last_depth() -> Dictionary:
	return history[-1] if not history.is_empty() else {}


# ------------------------------------------------------------------ checkpoint ("continue")
func save_checkpoint() -> void:
	SaveData.save_run(to_dict())
	SaveData.save_data()


func to_dict() -> Dictionary:
	var d := {
		"seed": seed_value, "depth": depth, "hp": hp, "embers": embers, "relics": relics,
		"flare": flare, "revive_used": revive_used, "kills": kills, "damage_dealt": damage_dealt,
		"damage_taken": damage_taken, "rooms_cleared": rooms_cleared, "time": time,
		"history": history, "moth": moth_counter,
	}
	d.merge(camp.to_dict())
	return d


func from_dict(d: Dictionary) -> void:
	active = true
	won = false
	seed_value = int(d.get("seed", 0))
	depth = clampi(int(d.get("depth", 1)), 1, Depths.FINAL)
	relics = []
	var saved_relics: Variant = d.get("relics", [])
	if saved_relics is Array:
		for id: Variant in saved_relics:
			if Relics.DEFS.has(id):
				relics.append(id)
	recompute_stats()
	hp = clampi(int(d.get("hp", max_hp)), 1, max_hp)
	embers = int(d.get("embers", 0))
	flare = float(d.get("flare", 0.0))
	revive_used = bool(d.get("revive_used", false))
	kills = int(d.get("kills", 0))
	damage_dealt = float(d.get("damage_dealt", 0.0))
	damage_taken = int(d.get("damage_taken", 0))
	rooms_cleared = int(d.get("rooms_cleared", 0))
	time = float(d.get("time", 0.0))
	var saved_history: Variant = d.get("history", [])
	history = saved_history if saved_history is Array else []
	moth_counter = int(d.get("moth", 0))
	killer = ""
	hurt_by = {}
	depth_log = DepthLog.new()
	wick_chat = []
	camp = CampVisit.from_dict(d)
	changed.emit()


func _process(delta: float) -> void:
	if active and not get_tree().paused:
		time += delta
		depth_log.time += delta
