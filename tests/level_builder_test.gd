extends SceneTree

const LevelParser = preload("res://game/level_parser.gd")
const LevelBuilder = preload("res://game/level_builder.gd")

var checks: int = 0
var failures: int = 0
var parser := LevelParser.new()


func _initialize() -> void:
	run.call_deferred()


func load_level(path: String, replace_from: String = "", replace_to: String = "") -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if not replace_from.is_empty():
		text = text.replace(replace_from, replace_to)
	return parser.parse(text, path)


func run() -> void:
	var builder := LevelBuilder.new()
	check(LevelBuilder.cell_to_world(Vector2i(0, 2)) == Vector2(16, 96), "cell_to_world gives the feet position.")
	var fixture := load_level("res://tests/fixtures/controller.level")
	var solids := Node2D.new()
	root.add_child(solids)
	check(builder.build_solids(fixture, solids) == 1, "One floor row becomes one body.")
	var floor_body := solids.get_child(0) as StaticBody2D
	var floor_shape := floor_body.get_child(0) as CollisionShape2D
	check(
		floor_body.position == Vector2(480, 112) and (floor_shape.shape as RectangleShape2D).size == Vector2(960, 32),
		"The floor body covers the whole row.",
	)
	var graybox_solids := Node2D.new()
	root.add_child(graybox_solids)
	check(
		builder.build_solids(load_level("res://levels/00-graybox.level"), graybox_solids) == 6,
		"Gray box has 1 floor and 5 platforms.",
	)
	var one_way := 0
	for body: Node in graybox_solids.get_children():
		if (body.get_child(0) as CollisionShape2D).one_way_collision:
			one_way += 1
	check(one_way == 5, "Platforms collide from above only.")
	var entities := Node2D.new()
	root.add_child(entities)
	var built := builder.build_entities(fixture, entities)
	var task_ids: Array[String] = []
	for rack in built["racks"]:
		task_ids.append(rack.task_id)
	var expected_ids: Array[String] = ["r1", "r2", "r2", "o1"]
	check(task_ids == expected_ids, "One rack per anchor, in task order.")
	check(built["racks"][0].position == Vector2(112, 96), "Rack A stands at its anchor.")
	check(built["hazards"].size() == 1 and built["coolant"].size() == 1, "Hazards and coolant are built.")
	var checkpoint_x: Array[float] = []
	for node: Node2D in built["checkpoints"]:
		checkpoint_x.append(node.position.x)
	var expected_x: Array[float] = [208.0, 496.0, 752.0]
	check(checkpoint_x == expected_x, "Checkpoints are sorted from left to right.")
	check(built["exit"].position == Vector2(944, 96), "Exit stands at E.")
	var unsupported := load_level("res://tests/fixtures/controller.level")
	unsupported["header"]["tasks"][2]["type"] = "dance"
	var other := Node2D.new()
	root.add_child(other)
	check(
		builder.build_entities(unsupported, other).is_empty()
		and builder.error_message == "Task type 'dance' is not built yet.",
		"Unsupported task types are reported.",
	)
	for node: Node in [solids, graybox_solids, entities, other]:
		node.queue_free()
	await process_frame
	print("LEVEL_BUILDER_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
