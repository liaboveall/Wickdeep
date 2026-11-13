class_name JsonFile
extends RefCounted
## Reads and writes JSON dictionaries. Writes go to a temporary file first, so a crash or a full
## disk half-way through never leaves a truncated save behind.


## Returns {} when the file is missing, unreadable or not a JSON object.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_warning("%s is not valid JSON (line %d): ignored" % [path, json.get_error_line()])
		return {}
	return json.data if json.data is Dictionary else {}


static func write(path: String, data: Dictionary, indent := "") -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, indent))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("Cannot replace %s (error %d)" % [path, err])
		return false
	return true


static func remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
