extends RefCounted

const ART_ROOT := "res://art/cel-shift/"
const GROUPS: Array[String] = ["tiles", "hazards", "props", "ui"]

var error_message: String = ""
var _frames: Dictionary = {}
var _fps: Dictionary = {}


func load_all() -> bool:
	for group: String in GROUPS:
		if not load_group(group):
			return false
	return true


func load_group(group: String) -> bool:
	var path := ART_ROOT + group + "/manifest.json"
	if not FileAccess.file_exists(path):
		return _fail("Pending artwork: sprite manifest is missing: " + path)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("assets") is Dictionary:
		return _fail("Invalid sprite manifest: " + path)
	for asset_name: String in data["assets"]:
		var entry: Dictionary = data["assets"][asset_name]
		var size := Vector2(entry["cell"][0], entry["cell"][1])
		var textures: Array[Texture2D] = []
		for relative: Variant in entry["frames"]:
			var texture_path := ART_ROOT + group + "/" + String(relative)
			if not ResourceLoader.exists(texture_path):
				return _fail("Pending artwork: missing or unimported sprite frame: " + texture_path)
			var texture := load(texture_path) as Texture2D
			if texture == null or texture.get_size() != size:
				return _fail("Sprite frame has the wrong size: " + texture_path)
			textures.append(texture)
		_frames[group + "/" + asset_name] = textures
		_fps[group + "/" + asset_name] = float(entry.get("fps", 1))
	return true


func has(group: String, asset_name: String) -> bool:
	return _frames.has(group + "/" + asset_name)


func frame_count(group: String, asset_name: String) -> int:
	return _frames.get(group + "/" + asset_name, []).size()


func texture(group: String, asset_name: String, frame: int = 0) -> Texture2D:
	var key := group + "/" + asset_name
	if not _frames.has(key) or frame < 0 or frame >= _frames[key].size():
		_fail("Unknown sprite: %s frame %d" % [key, frame])
		return null
	return _frames[key][frame]


func sprite_frames(group: String, asset_name: String) -> SpriteFrames:
	var key := group + "/" + asset_name
	if not _frames.has(key):
		_fail("Unknown sprite: " + key)
		return null
	var frames := SpriteFrames.new()
	frames.set_animation_speed(&"default", _fps[key])
	frames.set_animation_loop(&"default", true)
	for texture_frame: Texture2D in _frames[key]:
		frames.add_frame(&"default", texture_frame)
	return frames


func _fail(message: String) -> bool:
	error_message = message
	return false
