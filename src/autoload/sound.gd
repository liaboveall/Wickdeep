extends Node
## Sound effects (pooled players with per-sound throttling) and cross-faded looping music.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL := 24
const LOOPING := ["camp", "moss", "ash", "sanctum", "boss"]

var _sfx := {}
var _music_cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var current_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	var dir := DirAccess.open(SFX_DIR)
	if dir:
		for f in dir.get_files():
			var file := f.trim_suffix(".import").trim_suffix(".remap")
			if file.ends_with(".wav") and not _sfx.has(file.get_basename()):
				_sfx[file.get_basename()] = load(SFX_DIR + file)
	Settings.apply()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


## Play a sound effect. pitch_var randomises pitch by +-pitch_var.
func play(sound: String, volume_db := 0.0, pitch := 1.0, pitch_var := 0.0) -> void:
	var stream: AudioStream = _sfx.get(sound)
	if stream == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 35:
		return
	_last_played[sound] = now
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch + randf_range(-pitch_var, pitch_var))
	p.play()


func music(track: String, fade := 1.0) -> void:
	if track == current_music:
		return
	current_music = track
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_music_b, "volume_db", -80.0, fade)
	if track == "":
		return
	var stream := _music_stream(track)
	if stream == null:
		return
	_music_a.stream = stream
	_music_a.volume_db = -40.0
	_music_a.play()
	tw.tween_property(_music_a, "volume_db", 0.0, fade)


func stop_music(fade := 1.0) -> void:
	music("", fade)


func _music_stream(track: String) -> AudioStream:
	if _music_cache.has(track):
		return _music_cache[track]
	var path := MUSIC_DIR + track + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var s = load(path)
	if s is AudioStreamWAV:
		var wav := s as AudioStreamWAV
		# Looping tracks are set to loop in their .import files; only patch it if that was lost.
		if track in LOOPING and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav = wav.duplicate() as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(floor(wav.get_length() * wav.mix_rate)) - 1
		s = wav
	_music_cache[track] = s
	return s
