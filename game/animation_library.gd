extends RefCounted

# gdlint: disable=max-returns

const ART_ROOT := "res://art/cel-shift/animations/"
const VARIANTS: Array[StringName] = [
	&"man-midcreek",
	&"woman-midcreek",
]
const CLIPS: Array[StringName] = [
	&"idle",
	&"walk",
	&"run",
	&"jump",
	&"slide",
	&"primary",
	&"secondary",
	&"reaction",
	&"signal",
]
const FRAME_COUNTS: Array[int] = [6, 8, 8, 6, 4, 6, 8, 4, 6]

var variants: Dictionary[StringName, SpriteFrames] = {}
var error_message: String = ""


func load_manifest() -> bool:
	variants.clear()
	error_message = ""
	var path := ART_ROOT + "manifest.json"
	if not FileAccess.file_exists(path):
		return _fail("Pending artwork: animation manifest is missing.\n" + path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _fail("Cannot open animation manifest: %s" % FileAccess.get_open_error())
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _fail(
			(
				"Invalid animation JSON, line %d: %s"
				% [
					parser.get_error_line(),
					parser.get_error_message(),
				]
			)
		)
	if not parser.data is Dictionary:
		return _fail("Animation manifest must be an object.")
	var manifest: Dictionary = parser.data
	if manifest.get("version") != 1:
		return _fail("Animation manifest requires version 1.")
	if not _is_pair(manifest.get("cell_size"), 208, 208) or not _is_pair(manifest.get("pivot"), 104, 184):
		return _fail("Animation artwork requires 208x208 cells and pivot [104,184].")
	if not manifest.get("variants") is Dictionary:
		return _fail("Animation manifest requires a variants object.")
	var entries: Dictionary = manifest["variants"]
	if entries.size() != VARIANTS.size():
		return _fail("Animation manifest requires exactly man-midcreek and woman-midcreek.")
	var seen_paths: Dictionary[String, bool] = {}
	for variant: StringName in VARIANTS:
		if not entries.get(String(variant)) is Dictionary:
			return _fail("Missing animation variant: " + String(variant))
		var entry: Dictionary = entries[String(variant)]
		if not entry.get("animations") is Dictionary:
			return _fail("Missing animations object: " + String(variant))
		var clips: Dictionary = entry["animations"]
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		for index: int in range(CLIPS.size()):
			if not _load_clip(frames, variant, clips, index, seen_paths):
				variants.clear()
				return false
		variants[variant] = frames
	return true


func _load_clip(
	frames: SpriteFrames,
	variant: StringName,
	clips: Dictionary,
	index: int,
	seen_paths: Dictionary[String, bool],
) -> bool:
	var clip: StringName = CLIPS[index]
	var context := "%s/%s" % [variant, clip]
	if not clips.get(String(clip)) is Dictionary:
		return _fail("Missing animation clip: " + context)
	var data: Dictionary = clips[String(clip)]
	var fps_value: Variant = data.get("fps")
	if not (fps_value is float or fps_value is int):
		return _fail("Animation fps must be numeric: " + context)
	var fps := float(fps_value)
	if not is_finite(fps) or fps <= 0.0:
		return _fail("Animation fps must be finite and positive: " + context)
	if not data.get("loop") is bool or not data.get("frames") is Array:
		return _fail("Animation requires loop and frames: " + context)
	if bool(data["loop"]) != (index < 3):
		return _fail("Only idle, walk and run must loop: " + context)
	var paths: Array = data["frames"]
	if paths.size() != FRAME_COUNTS[index]:
		return _fail(
			(
				"%s requires %d authored frames, found %d."
				% [
					context,
					FRAME_COUNTS[index],
					paths.size(),
				]
			)
		)
	frames.add_animation(clip)
	frames.set_animation_speed(clip, fps)
	frames.set_animation_loop(clip, bool(data["loop"]))
	for value: Variant in paths:
		if not value is String:
			return _fail("Animation frame path must be a string: " + context)
		var relative_path: String = value
		if (
			not relative_path.begins_with("frames/")
			or not relative_path.ends_with(".png")
			or relative_path.simplify_path() != relative_path
			or ".." in relative_path
			or ":" in relative_path
			or "\\" in relative_path
		):
			return _fail("Invalid relative animation frame path: " + relative_path)
		var path := ART_ROOT + relative_path
		if seen_paths.has(path):
			return _fail("Animation reuses a frame path: " + relative_path)
		if not ResourceLoader.exists(path):
			return _fail("Pending artwork: missing or unimported animation frame.\n" + path)
		var texture := load(path) as Texture2D
		if texture == null or texture.get_size() != Vector2(208, 208):
			return _fail("Animation frame must be a 208x208 texture: " + path)
		seen_paths[path] = true
		frames.add_frame(clip, texture)
	return true


func _is_pair(value: Variant, first: int, second: int) -> bool:
	return value is Array and value.size() == 2 and value[0] == first and value[1] == second


func _fail(message: String) -> bool:
	error_message = message
	variants.clear()
	push_error(message)
	return false
