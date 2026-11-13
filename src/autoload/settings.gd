extends Node
## Player settings, stored in user://settings.cfg.
## The DeepSeek API key is typed in by the player in the settings screen (or read from the
## DEEPSEEK_API_KEY environment variable). It is never bundled with the game.

signal changed

const PATH := "user://settings.cfg"
const DEFAULT_BASE_URL := "https://api.deepseek.com"
const DEFAULT_MODEL := "deepseek-flash"
const API_KEY_ENV := "DEEPSEEK_API_KEY"

## [section, key, property]: the one list both loading and saving go through.
const FIELDS := [
	["audio", "master", "master_volume"],
	["audio", "music", "music_volume"],
	["audio", "sfx", "sfx_volume"],
	["video", "fullscreen", "fullscreen"],
	["video", "shake", "screen_shake"],
	["video", "damage_numbers", "damage_numbers"],
	["ai", "enabled", "ai_enabled"],
	["ai", "api_key", "api_key"],
	["ai", "base_url", "base_url"],
	["ai", "model", "model"],
]

## Test sessions set this to false: they change settings in memory and must not write them back.
var persist := true

var master_volume := 0.8
var music_volume := 0.7
var sfx_volume := 0.8
var fullscreen := false
var screen_shake := 1.0
var damage_numbers := true
var ai_enabled := true
var api_key := ""
var base_url := DEFAULT_BASE_URL
var model := DEFAULT_MODEL


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for field: Array in FIELDS:
		var current: Variant = get(field[2])
		var value: Variant = cfg.get_value(field[0], field[1], current)
		if current is float and value is int:
			value = float(value)
		# a hand-edited file may hold the wrong type; keep the default rather than crash later
		if typeof(value) == typeof(current):
			set(field[2], value)
	set_ai(ai_enabled, api_key, base_url, model)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for field: Array in FIELDS:
		cfg.set_value(field[0], field[1], get(field[2]))
	if persist:
		cfg.save(PATH)
	changed.emit()


## Store the AI connection fields, trimming whitespace and falling back to the defaults.
func set_ai(enabled: bool, key: String, url: String, model_name: String) -> void:
	ai_enabled = enabled
	api_key = key.strip_edges()
	base_url = url.strip_edges() if url.strip_edges() != "" else DEFAULT_BASE_URL
	model = model_name.strip_edges() if model_name.strip_edges() != "" else DEFAULT_MODEL


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply()
	save_settings()


func apply() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


func _set_bus(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


func has_env_api_key() -> bool:
	return OS.get_environment(API_KEY_ENV).strip_edges() != ""


## The key actually used for requests: settings first, then the environment variable.
func effective_api_key() -> String:
	if api_key != "":
		return api_key
	return OS.get_environment(API_KEY_ENV).strip_edges()


func ai_available() -> bool:
	return ai_enabled and effective_api_key() != ""
