extends SceneTree

const Builder = preload("res://game/level_builder.gd")
const Library = preload("res://game/sprite_library.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var art := Library.new()
	check(art.load_all() and art.load_group("work"), "Production work sprites load.")
	var data := {
		"anchors": {}, "header": {"tasks": [{"id": "power", "type": "restore_power", "required": true, "sites": [[4, 2]], "resources": [{"kind": "fuse", "cell": [2, 2]}]}]},
		"hazards": [], "lifts": [], "coolant": [], "checkpoints": [], "exit": Vector2i(8, 2),
	}
	var builder := Builder.new()
	builder.art = art
	var parent := Node2D.new()
	art._frames.erase("work/fuse")
	check(builder.build_entities(data, parent).is_empty() and builder.error_message.contains("work/fuse"), "Missing required work sprite stops construction before drawing.")
	parent.free()
	art.load_group("work")
	art._frames["work/fire"].resize(3)
	data["header"]["tasks"] = []
	data["hazards"] = [{"kind": "fire", "cell": Vector2i(5, 2)}]
	parent = Node2D.new()
	check(builder.build_entities(data, parent).is_empty() and builder.error_message.contains("fire"), "Incomplete fire animation stops construction.")
	parent.free()
	print("WORK_ART_CONTRACT_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
