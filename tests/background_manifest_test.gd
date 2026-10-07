extends SceneTree

var checks := 0
var failures := 0
const TILE := 32


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var path := "res://game/background_set.gd"
	check(ResourceLoader.exists(path), "Ordered background manifest loader exists.")
	if not ResourceLoader.exists(path):
		finish()
		return
	var script: Script = load(path)
	var background = script.new()
	var layer := {
		"name": "Far", "texture": "res://art/cel-shift/environment/layers/far.png",
		"scroll": 0.2, "tint": [0.42, 0.47, 0.56], "coverage": "native", "scale": 2.0,
	}
	check(background.parse({"version": 1, "layers": [layer]}), "Valid ordered layer loads.")
	check(background.layers.size() == 1 and background.layers[0]["texture"] is Texture2D, "The active set loads its runtime texture.")
	check(not background.validate_level_height(640), "A far texture with the wrong normalized height fails level validation.")
	check(background.error_message.contains("res://art/cel-shift/environment/layers/far.png"), "The size mismatch names the texture file.")
	for bad: Variant in [
		null, [], {}, {"version": 2, "layers": [layer]}, {"version": 1, "layers": []},
		{"version": 1, "layers": [layer, layer]},
	]:
		check(not background.parse(bad), "Malformed set fails with no layers.")
		check(not background.error_message.is_empty() and background.layers.is_empty(), "Failure reports an error and clears old textures.")
	for field: String in ["name", "texture", "scroll", "tint", "coverage", "scale"]:
		var invalid: Dictionary = layer.duplicate(true)
		invalid.erase(field)
		check(not background.parse({"version": 1, "layers": [invalid]}), "Missing layer field fails: " + field)
	for change: Dictionary in [
		{"texture": "res://art/cel-shift/environment/missing.png"},
		{"texture": "res://game/player.gd"}, {"scroll": -1.0}, {"scroll": INF},
		{"tint": [1.0, -0.1, 0.0]}, {"tint": [1.0, 0.5]}, {"scale": 0.0},
		{"scale": NAN}, {"coverage": "unknown"}, {"name": "bad/name"},
	]:
		var invalid: Dictionary = layer.duplicate(true)
		invalid.merge(change, true)
		check(not background.parse({"version": 1, "layers": [invalid]}), "Invalid layer is rejected: " + str(change))
	for change: Dictionary in [
		{"scale": 1.5}, {"name": "Far", "scale": 1.0},
		{"name": "Shell", "scale": 1.0}, {"name": "Equipment", "scale": 2.0},
		{"name": "Racks", "scale": 2.0},
	]:
		var invalid_scale: Dictionary = layer.duplicate(true)
		invalid_scale.merge(change, true)
		check(not background.parse({"version": 1, "layers": [invalid_scale]}), "Invalid native scale is rejected: " + str(change))
	var heights := campaign_background_heights()
	for name: String in heights.keys():
		check(background.load_set(name), "Existing background manifest loads: " + name)
		if background.layers.size() != 2:
			check(false, "Existing sets retain two layers.")
			continue
		check(background.validate_level_height(heights[name]), name + " far layer is sized exactly to the campaign level height.")
		for item: Dictionary in background.layers:
			var layer_name := String(item["name"]).to_lower()
			if layer_name in ["equipment", "racks"]:
				check(is_equal_approx(item["scale"], 1.0), name + " " + layer_name + " uses 1.0 world px per texel.")
				check(item["coverage"] == "native", name + " " + layer_name + " uses only native scale.")
			elif layer_name in ["far", "shell"]:
				check(is_equal_approx(item["scale"], 2.0), name + " " + layer_name + " uses 2.0 world px per texel.")
				check(item["coverage"] == "native", name + " " + layer_name + " uses only native scale.")
	check(not background.load_set("../layers"), "Set names cannot escape their directory.")

	var bad_level := "user://background-wrong-height.level"
	var bad_file := FileAccess.open(bad_level, FileAccess.WRITE)
	bad_file.store_string(FileAccess.get_file_as_string("res://levels/06-cooling-gallery.level").replace('"cooling-gallery"', '"cold-aisle"'))
	bad_file.close()
	var level_scene := load("res://game/level.tscn")
	var bad_instance = level_scene.instantiate()
	bad_instance.level_path = bad_level
	root.add_child(bad_instance)
	check(bad_instance.error_message.contains("Background texture height mismatch"), "User level with wrong-height far texture fails clearly.")
	check(bad_instance.error_message.contains("res://art/cel-shift/environment/cold-aisle/far.png"), "User level size error names the far texture.")
	bad_instance.queue_free()
	await process_frame
	DirAccess.remove_absolute(bad_level)
	finish()


func campaign_background_heights() -> Dictionary:
	var heights := {}
	for file: String in DirAccess.get_files_at("res://levels"):
		if not file.ends_with(".level") or file.begins_with("00-"):
			continue
		var text := FileAccess.get_file_as_string("res://levels/" + file).replace("\r\n", "\n")
		var parts := text.split("\n---\n")
		check(parts.size() == 2, file + " has a JSON header and grid.")
		if parts.size() != 2:
			continue
		var header: Dictionary = JSON.parse_string(parts[0])
		var rows := parts[1].strip_edges(false, true).split("\n")
		var height := rows.size() * TILE
		var background: String = header["background"]
		if heights.has(background):
			check(heights[background] == height, background + " is not shared by levels with different heights.")
		else:
			heights[background] = height
	return heights


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)


func finish() -> void:
	print("BACKGROUND_MANIFEST_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
