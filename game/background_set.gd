extends RefCounted

const ROOT := "res://art/cel-shift/environment/"

var layers: Array[Dictionary] = []
var error_message := ""


func load_set(name: String) -> bool:
	if not _valid_name(name):
		return _fail("Invalid background set name: " + name)
	var path := ROOT + name + "/manifest.json"
	if not FileAccess.file_exists(path):
		return _fail("Pending artwork: missing background manifest: " + path)
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return _fail("Invalid background JSON: " + path)
	return parse(json.data)


func parse(data: Variant) -> bool:
	layers.clear()
	error_message = ""
	if not data is Dictionary or data.get("version") != 1 or not data.get("layers") is Array or data["layers"].is_empty():
		return _fail("Background manifest needs version 1 and a nonempty layers array.")
	var names := {}
	var pending: Array[Dictionary] = []
	for entry: Variant in data["layers"]:
		if not entry is Dictionary:
			return _fail("Background layer must be an object.")
		if not entry.get("name") is String or not _valid_name(entry["name"]) or names.has(entry["name"]):
			return _fail("Background layer names must be unique identifiers.")
		names[entry["name"]] = true
		var path: Variant = entry.get("texture")
		if not path is String or not path.begins_with(ROOT) or ".." in path or not path.ends_with(".png"):
			return _fail("Background textures must be PNG files in the environment directory.")
		if not _number(entry.get("scroll")) or float(entry["scroll"]) < 0.0 or float(entry["scroll"]) > 1.0:
			return _fail("Background scroll must be between zero and one.")
		if not _number(entry.get("scale")) or float(entry["scale"]) <= 0.0:
			return _fail("Background scale must be finite and positive.")
		if entry.get("coverage") not in ["level", "native"]:
			return _fail("Background coverage must be level or native.")
		var tint: Variant = entry.get("tint")
		if not tint is Array or tint.size() != 3:
			return _fail("Background tint needs three color components.")
		for value: Variant in tint:
			if not _number(value) or float(value) < 0.0 or float(value) > 1.0:
				return _fail("Background tint components must be between zero and one.")
		if not ResourceLoader.exists(path):
			return _fail("Pending artwork: missing background texture: " + path)
		var texture := load(path) as Texture2D
		if texture == null:
			return _fail("Pending artwork: invalid background texture: " + path)
		pending.append({
			"name": entry["name"], "texture": texture, "path": path,
			"scroll": float(entry["scroll"]), "scale": float(entry["scale"]),
			"coverage": entry["coverage"], "tint": Color(tint[0], tint[1], tint[2]),
		})
	layers = pending
	return true


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _valid_name(value: String) -> bool:
	if value.is_empty():
		return false
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_":
			return false
	return true


func _fail(message: String) -> bool:
	layers.clear()
	error_message = message
	return false
