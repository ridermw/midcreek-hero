extends SceneTree

const SpriteLibrary = preload("res://game/sprite_library.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var library := SpriteLibrary.new()
	check(library.load_all(), "All sprite groups load: " + library.error_message)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/cel-shift/catalog.json"))
	var all_loaded := true
	for asset: Dictionary in catalog["assets"]:
		var size := Vector2(asset["cell"][0], asset["cell"][1])
		for frame: int in range(int(asset["frames"])):
			var texture := library.texture(asset["group"], asset["name"], frame)
			if texture == null or texture.get_size() != size:
				all_loaded = false
				push_error("Bad sprite: %s/%s %d" % [asset["group"], asset["name"], frame])
	check(all_loaded, "Every catalog frame loads at its cell size.")
	check(library.texture("ui", "nope") == null, "Unknown sprites return null.")
	check(library.error_message.contains("ui/nope"), "Unknown sprites set an error message.")
	var frames := library.sprite_frames("tiles", "checkpoint-on")
	check(frames != null and frames.get_frame_count(&"default") == 4, "Animated sprites build SpriteFrames.")
	check(library.frame_count("props", "coolant") == 4, "frame_count reports animation frames.")
	print("SPRITE_LIBRARY_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
