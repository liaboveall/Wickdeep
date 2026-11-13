extends Node
## Persistent progress across runs (save.json) and the mid-run checkpoint (run.json).
##
## Both live in user://. Automated sessions (unit tests, the autoplay bot, screenshot runs) switch
## to user://sandbox/ first, so they can never touch a real player's progress.

const SAVE_FILE := "save.json"
const RUN_FILE := "run.json"
const SANDBOX_DIR := "user://sandbox/"
const VERSION := 1
const MEMORY_LIMIT := 6
const MEMORY_NOTE_LENGTH := 40
const EPITAPH_LIMIT := 20
const AFFINITY_RANGE := 10

var dir := "user://"

var runs := 0
var wins := 0
var best_depth := 0
var total_kills := 0
var granny_affinity := 0          # -10 .. 10, shifts her mood and starting prices
var granny_memory: Array = []     # short notes she remembers about the player
var wick_memory: Array = []       # short notes Wick remembers from earlier runs
var epitaphs: Array = []          # {title, text, depth, won}
var seen_relics: Array = []
var seen_enemies: Array = []


func _ready() -> void:
	load_data()


## Point saving at a throw-away folder and start from a blank profile.
func use_sandbox() -> void:
	dir = SANDBOX_DIR
	JsonFile.remove(save_path())
	JsonFile.remove(run_path())
	reset()


func is_sandboxed() -> bool:
	return dir == SANDBOX_DIR


func save_path() -> String:
	return dir + SAVE_FILE


func run_path() -> String:
	return dir + RUN_FILE


func reset() -> void:
	runs = 0
	wins = 0
	best_depth = 0
	total_kills = 0
	granny_affinity = 0
	granny_memory = []
	wick_memory = []
	epitaphs = []
	seen_relics = []
	seen_enemies = []


func load_data() -> void:
	var d := JsonFile.read(save_path())
	if d.is_empty():
		return
	runs = int(d.get("runs", 0))
	wins = int(d.get("wins", 0))
	best_depth = int(d.get("best_depth", 0))
	total_kills = int(d.get("total_kills", 0))
	granny_affinity = clampi(int(d.get("granny_affinity", 0)), -AFFINITY_RANGE, AFFINITY_RANGE)
	granny_memory = _list(d, "granny_memory")
	wick_memory = _list(d, "wick_memory")
	epitaphs = _list(d, "epitaphs")
	seen_relics = _list(d, "seen_relics")
	seen_enemies = _list(d, "seen_enemies")


func save_data() -> void:
	JsonFile.write(save_path(), {
		"version": VERSION,
		"runs": runs, "wins": wins, "best_depth": best_depth, "total_kills": total_kills,
		"granny_affinity": granny_affinity, "granny_memory": granny_memory,
		"wick_memory": wick_memory, "epitaphs": epitaphs,
		"seen_relics": seen_relics, "seen_enemies": seen_enemies,
	}, "\t")


static func _list(d: Dictionary, key: String) -> Array:
	var v: Variant = d.get(key, [])
	return v if v is Array else []


# ------------------------------------------------------------------ what the characters remember
## Keep a short note in one of the memory lists (oldest notes drop off the front).
func remember(list: Array, note: String) -> void:
	note = note.strip_edges()
	if note == "" or note in list:
		return
	list.append(note.left(MEMORY_NOTE_LENGTH))
	while list.size() > MEMORY_LIMIT:
		list.pop_front()


func mark_seen(list: Array, id: String) -> void:
	if not id in list:
		list.append(id)


func shift_granny_affinity(delta: int) -> void:
	granny_affinity = clampi(granny_affinity + delta, -AFFINITY_RANGE, AFFINITY_RANGE)


func add_epitaph(title: String, text: String, depth: int, won: bool) -> void:
	epitaphs.append({"title": title, "text": text, "depth": depth, "won": won})
	while epitaphs.size() > EPITAPH_LIMIT:
		epitaphs.pop_front()


# ------------------------------------------------------------------ mid-run checkpoint
## Written when arriving at the camp; cleared when the run ends.
func has_run() -> bool:
	return FileAccess.file_exists(run_path())


func save_run(d: Dictionary) -> void:
	JsonFile.write(run_path(), d)


func load_run() -> Dictionary:
	return JsonFile.read(run_path())


func clear_run() -> void:
	JsonFile.remove(run_path())
