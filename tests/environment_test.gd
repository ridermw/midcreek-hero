extends SceneTree

const DataHallEnvironment = preload("res://game/environment.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var environment := DataHallEnvironment.new()
	root.add_child(environment)
	var loaded := environment.load_art()
	check(loaded, "Normalized environment layers load.")
	check(environment.error_message.is_empty(), "Environment reports no asset error.")
	check(environment.get_child_count() == 3, "All three layers exist.")
	if loaded:
		for index: int in range(environment.get_child_count()):
			var layer := environment.get_child(index)
			var expected_size := Vector2(640, 96 if index == 2 else 360)
			check(layer.get_child_count() == 4, "Each layer has four chunks.")
			for chunk: int in range(layer.get_child_count()):
				var tile := layer.get_child(chunk) as Sprite2D
				check(tile.texture.get_size() == expected_size, "Chunk has the runtime size.")
				check(not tile.centered, "Chunk uses its top-left origin.")
				check(
					tile.position == Vector2(chunk * 640, 300 if index == 2 else 0),
					"Chunk has the contracted position.",
				)
		environment.follow_camera(320.0)
		check(environment.far_layer.position.x == 0.0, "Far layer starts at the origin.")
		environment.follow_camera(640.0)
		check(environment.far_layer.position.x == 269.0, "Far layer follows camera parallax.")
	environment.queue_free()
	await process_frame
	print("ENVIRONMENT_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
