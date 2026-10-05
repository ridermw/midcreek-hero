extends RefCounted

const LEVEL_IDS: Array[String] = ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15"]
const DEFAULT_SETTINGS := {"music_volume": 0.8, "sfx_volume": 0.9}
const CONTROL_DISPLAYS := ["keyboard", "gamepad", "touch"]

var path: String
var character: String = "man"
var levels: Dictionary = {}
var unlocked: Array[String] = ["01"]
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var warning_message := ""


func _init(save_path: String = "user://save.json") -> void:
	path = save_path


static func next_level_id(level_id: String) -> String:
	var index := LEVEL_IDS.find(level_id)
	if index < 0 or index + 1 >= LEVEL_IDS.size():
		return ""
	return LEVEL_IDS[index + 1]


func load_data() -> void:
	_reset()
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	var parsed := json.parse(FileAccess.get_file_as_string(path)) == OK
	var data: Variant = json.data if parsed else null
	if not _is_valid(data):
		DirAccess.rename_absolute(path, path.get_basename() + ".corrupt.json")
		return
	character = String(data.get("character", "man"))
	for level_id: String in data.get("levels", {}):
		var entry: Dictionary = data["levels"][level_id]
		levels[level_id] = {
			"stars": int(entry.get("stars", 0)),
			"best_optional": int(entry.get("best_optional", 0)),
		}
		if entry.has("best_seconds"):
			levels[level_id]["best_seconds"] = float(entry["best_seconds"])
	for level_id: Variant in data.get("unlocked", []):
		if String(level_id) not in unlocked:
			unlocked.append(String(level_id))
	for level_id: String in LEVEL_IDS.slice(4):
		var next := next_level_id(level_id)
		if stars(level_id) > 0 and not next.is_empty() and next not in unlocked:
			unlocked.append(next)
	for key: String in data.get("settings", {}):
		var value: Variant = data["settings"][key]
		if key == "control_display":
			if value is String and value in CONTROL_DISPLAYS:
				settings[key] = value
			else:
				warning_message = "The saved control display was invalid. Using the device default; progress is safe."
		else:
			settings[key] = clampf(float(value), 0.0, 1.0)


func save() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(
		JSON.stringify(
			{
				"version": 1,
				"character": character,
				"levels": levels,
				"unlocked": unlocked,
				"settings": settings,
			},
			"  ",
		)
	)
	file.flush()
	var success := file.get_error() == OK
	file.close()
	return success


func record(level_id: String, earned_stars: int, seconds: float, optional_done: int) -> void:
	var entry: Dictionary = levels.get(level_id, {})
	entry["stars"] = maxi(int(entry.get("stars", 0)), earned_stars)
	var best: float = float(entry.get("best_seconds", INF))
	entry["best_seconds"] = minf(best, seconds)
	entry["best_optional"] = maxi(int(entry.get("best_optional", 0)), optional_done)
	levels[level_id] = entry
	var next := next_level_id(level_id)
	if not next.is_empty() and next not in unlocked:
		unlocked.append(next)


func is_unlocked(level_id: String) -> bool:
	return level_id in unlocked


func stars(level_id: String) -> int:
	return int(levels.get(level_id, {}).get("stars", 0))


func best_seconds(level_id: String) -> float:
	return float(levels.get(level_id, {}).get("best_seconds", 0.0))


func best_optional(level_id: String) -> int:
	return int(levels.get(level_id, {}).get("best_optional", 0))


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_count(value: Variant) -> bool:
	return _is_number(value) and float(value) >= 0.0 and float(value) == floorf(float(value))


func _is_valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1.0:
		return false
	if data.has("character") and String(data["character"]) not in ["man", "woman"]:
		return false
	if data.has("unlocked"):
		if not data["unlocked"] is Array:
			return false
		for level_id: Variant in data["unlocked"]:
			if not level_id is String or level_id not in LEVEL_IDS:
				return false
	if data.has("levels"):
		if not data["levels"] is Dictionary:
			return false
		for level_id: Variant in data["levels"]:
			var entry: Variant = data["levels"][level_id]
			if level_id not in LEVEL_IDS or not entry is Dictionary:
				return false
			var earned: Variant = entry.get("stars", 0)
			if not _is_count(earned) or float(earned) > 3.0:
				return false
			if entry.has("best_seconds") and not (_is_number(entry["best_seconds"]) and float(entry["best_seconds"]) >= 0.0):
				return false
			if entry.has("best_optional") and not _is_count(entry["best_optional"]):
				return false
	if data.has("settings"):
		if not data["settings"] is Dictionary:
			return false
		for key: Variant in data["settings"]:
			if key == "control_display":
				continue
			if key not in DEFAULT_SETTINGS or not _is_number(data["settings"][key]):
				return false
	return true


func _reset() -> void:
	character = "man"
	levels = {}
	unlocked = ["01"]
	settings = DEFAULT_SETTINGS.duplicate()
	warning_message = ""
