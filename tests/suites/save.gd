extends "res://tests/test_suite.gd"
## Save files and settings: round trips, corrupt files, limits, and the sandbox.

const SCRATCH := "user://sandbox/test_scratch.json"


func before_each() -> void:
	fresh_run()
	JsonFile.remove(SCRATCH)


func test_sandbox() -> void:
	check(SaveData.is_sandboxed(), "tests run in the sandbox")
	check(SaveData.save_path().begins_with(SaveData.SANDBOX_DIR), "progress goes to the sandbox")
	check(SaveData.run_path().begins_with(SaveData.SANDBOX_DIR), "so does the checkpoint")
	check(not Settings.persist, "settings are not written in test sessions")


func test_json_file_round_trip() -> void:
	check(JsonFile.read(SCRATCH).is_empty(), "missing file reads as empty")
	check(JsonFile.write(SCRATCH, {"a": 1, "list": ["x", "y"], "中文": "可以"}), "write succeeds")
	var back := JsonFile.read(SCRATCH)
	equal(int(back.a), 1, "number")
	equal(back.list, ["x", "y"], "list")
	equal(back["中文"], "可以", "unicode")
	check(not FileAccess.file_exists(SCRATCH + ".tmp"), "no temporary file left behind")
	check(JsonFile.write(SCRATCH, {"b": 2}), "overwrite succeeds")
	equal(JsonFile.read(SCRATCH).keys(), ["b"], "old content replaced")
	JsonFile.remove(SCRATCH)
	check(not FileAccess.file_exists(SCRATCH), "removed")


func test_corrupt_files_are_ignored() -> void:
	for garbage: String in ["", "{ not json", "[1, 2, 3]", "\"just a string\""]:
		var f := FileAccess.open(SCRATCH, FileAccess.WRITE)
		f.store_string(garbage)
		f.close()
		check(JsonFile.read(SCRATCH).is_empty(), "unreadable content gives {}: " + garbage)


func test_profile_round_trip() -> void:
	SaveData.wins = 3
	SaveData.best_depth = 4
	SaveData.total_kills = 321
	SaveData.shift_granny_affinity(7)
	SaveData.remember(SaveData.wick_memory, "他总是忘记买灯油")
	SaveData.mark_seen(SaveData.seen_enemies, "wisp")
	SaveData.add_epitaph("倔强的灯芯", "……", 2, false)
	SaveData.save_data()
	SaveData.reset()
	equal(SaveData.wins, 0, "reset clears the profile in memory")
	SaveData.load_data()
	equal(SaveData.wins, 3, "wins")
	equal(SaveData.best_depth, 4, "best depth")
	equal(SaveData.total_kills, 321, "kills")
	equal(SaveData.granny_affinity, 7, "affinity")
	equal(SaveData.wick_memory, ["他总是忘记买灯油"], "memories")
	equal(SaveData.seen_enemies, ["wisp"], "seen enemies")
	equal(SaveData.epitaphs[0].title, "倔强的灯芯", "epitaphs")
	equal(int(JsonFile.read(SaveData.save_path()).version), SaveData.VERSION, "version stamp")


func test_memory_limits() -> void:
	var notes: Array = []
	SaveData.remember(notes, "  ")
	equal(notes.size(), 0, "blank notes are not kept")
	SaveData.remember(notes, "同一件事")
	SaveData.remember(notes, "同一件事")
	equal(notes.size(), 1, "no duplicates")
	SaveData.remember(notes, "很".repeat(100))
	equal(notes[1].length(), SaveData.MEMORY_NOTE_LENGTH, "long notes are cut")
	for k in 20:
		SaveData.remember(notes, "第%d件事" % k)
	equal(notes.size(), SaveData.MEMORY_LIMIT, "only the latest few are kept")
	equal(notes[-1], "第19件事", "newest last")
	SaveData.shift_granny_affinity(100)
	equal(SaveData.granny_affinity, SaveData.AFFINITY_RANGE, "affinity capped")
	SaveData.shift_granny_affinity(-100)
	equal(SaveData.granny_affinity, -SaveData.AFFINITY_RANGE, "and floored")


func test_settings_fields() -> void:
	for field: Array in Settings.FIELDS:
		check(field[2] in Settings, "Settings has a property named " + field[2])
	var saved := [Settings.ai_enabled, Settings.api_key, Settings.base_url, Settings.model]
	Settings.set_ai(true, "  sk-test  ", "  ", "")
	equal(Settings.api_key, "sk-test", "key trimmed")
	equal(Settings.base_url, Settings.DEFAULT_BASE_URL, "blank URL falls back to the default")
	equal(Settings.model, Settings.DEFAULT_MODEL, "blank model falls back to the default")
	check(Settings.ai_available(), "enabled with a key")
	Settings.set_ai(false, "sk-test", "", "")
	check(not Settings.ai_available(), "disabled by the toggle")
	Settings.set_ai(saved[0], saved[1], saved[2], saved[3])
