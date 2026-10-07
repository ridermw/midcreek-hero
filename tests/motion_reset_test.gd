extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for path: String in ["entities/lift", "hazards/cable_snag", "hazards/moving_snag", "hazards/drone", "hazards/spark_arc"]:
		var node: Node2D = load("res://game/" + path + ".gd").new()
		node.position = Vector2(240, 416)
		root.add_child(node)
		node.set_physics_process(false)
		check(node.has_method("reset_motion"), path + " exposes an authored motion reset.")
		if node.has_method("reset_motion"):
			if path == "entities/lift":
				node._physics_process(1.7)
			else:
				node.advance(1.7)
			node.reset_motion()
			check(node.position == Vector2(240, 416) and node._time == 0.0, path + " returns to authored position and phase.")
			if "direction" in node:
				check(node.direction == 1.0, path + " returns to its authored direction.")
			if path in ["hazards/cable_snag", "hazards/moving_snag", "hazards/drone"]:
				node.active = false
				node.reset_motion()
				check(not node.active, path + " does not undo progress while resetting motion.")
		node.queue_free()
		await process_frame
	var level: Node = load("res://game/level.tscn").instantiate()
	level.level_path = "res://levels/03-cable-jungle.level"
	root.add_child(level)
	check(level.error_message.is_empty() and level.entities["work"].is_empty(), "Level 3 loads without work stations.")
	var movers: Array = level.entities["hazards"].filter(func(h) -> bool: return h.has_method("setup"))
	var authored: Array = movers.map(func(h) -> float: return h.position.x)
	for hazard in movers:
		hazard.advance(1.7)
	level._respawn()
	check(not movers.is_empty() and movers.map(func(h) -> float: return h.position.x) == authored, "Respawn resets moving hazards in levels without work stations.")
	level.queue_free()
	await process_frame
	print("MOTION_RESET_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
