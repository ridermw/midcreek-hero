extends RefCounted

const LEVEL_IDS: Array[String] = ["01", "02", "03", "04", "05"]
const DEFAULT_SETTINGS := {"music_volume": 0.8, "sfx_volume": 0.9}

var path: String
var character: String = "man"
var levels: Dictionary = {}
var unlocked: Array[String] = ["01"]
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()


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
	if not data is Dictionary or data.get("version") != 1.0:
		DirAccess.rename_absolute(path, path.get_basename() + ".corrupt.json")
		return
	character = String(data.get("character", "man"))
	if data.get("levels") is Dictionary:
		levels = data["levels"]
	if data.get("unlocked") is Array:
		for level_id: Variant in data["unlocked"]:
			if String(level_id) not in unlocked:
				unlocked.append(String(level_id))
	if data.get("settings") is Dictionary:
		settings.merge(data["settings"], true)


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
	file.close()
	return true


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


func _reset() -> void:
	character = "man"
	levels = {}
	unlocked = ["01"]
	settings = DEFAULT_SETTINGS.duplicate()
