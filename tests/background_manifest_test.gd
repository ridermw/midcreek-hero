extends SceneTree

var checks := 0
var failures := 0


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
		"scroll": 0.2, "tint": [0.42, 0.47, 0.56], "coverage": "level", "scale": 1.0,
	}
	check(background.parse({"version": 1, "layers": [layer]}), "Valid ordered layer loads.")
	check(background.layers.size() == 1 and background.layers[0]["texture"] is Texture2D, "The active set loads its runtime texture.")
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
	for name: String in ["cold-aisle", "hot-aisle", "cable-jungle", "power-room", "outage-night"]:
		check(background.load_set(name), "Existing background manifest loads: " + name)
		if background.layers.size() != 2:
			check(false, "Existing sets retain two layers.")
			continue
		var far: Dictionary = background.layers[0]
		var equipment: Dictionary = background.layers[1]
		check(far["name"] == "Far" and far["scroll"] == 0.2 and far["coverage"] == "level", "Existing distant composition is unchanged.")
		check(equipment["name"] == "Equipment" and equipment["scroll"] == 0.6 and equipment["scale"] == 1.0, "Existing equipment scale is unchanged.")
	check(not background.load_set("../layers"), "Set names cannot escape their directory.")
	finish()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)


func finish() -> void:
	print("BACKGROUND_MANIFEST_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
