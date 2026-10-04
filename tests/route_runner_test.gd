extends SceneTree

const RouteRunner = preload("res://game/route_runner.gd")
const DT := 1.0 / 60.0


class FakePlayer:
	extends RefCounted
	var position := Vector2.ZERO
	var use_override := false
	var input_override: Dictionary = {}


class FakeLevel:
	extends RefCounted
	var player := FakePlayer.new()
	var use_action_override := false
	var action_override: Dictionary = {}


var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var level := FakeLevel.new()
	var steps := [
		{"hold": ["move_right"], "seconds": 0.5},
		{"tap": "jump"},
		{"hold": ["move_right", "jump"], "until_x": 100.0, "max_seconds": 1.0},
		{"hold": ["repair"], "seconds": 0.1},
		{"wait": 0.1},
	]
	var runner := RouteRunner.new(steps)
	check(runner.error_message.is_empty(), "A valid route has no error.")
	runner.apply(level, DT)
	check(level.player.use_override and level.use_action_override, "The runner takes over input.")
	check(level.player.input_override.get("direction") == 1.0, "move_right sets direction 1.")
	for i: int in range(30):
		runner.apply(level, DT)
	check(level.player.input_override.get("jump_pressed") == true, "tap presses jump for one frame.")
	runner.apply(level, DT)
	check(level.player.input_override.get("jump_pressed") == true, "A hold with jump presses jump on its first frame.")
	runner.apply(level, DT)
	check(not level.player.input_override.has("jump_pressed") and level.player.input_override.get("jump_held") == true, "A held jump stays held without a new press.")
	level.player.position.x = 120.0
	runner.apply(level, DT)
	check(level.action_override.get(&"repair") == true, "until_x ends the step when x is reached.")
	for i: int in range(6):
		runner.apply(level, DT)
	check(level.action_override.is_empty() and level.player.input_override.get("direction", 0.0) == 0.0, "wait releases all input.")
	for i: int in range(6):
		runner.apply(level, DT)
	check(runner.done() and not runner.failed, "The route finishes.")
	var stuck := RouteRunner.new([{"hold": ["move_right"], "until_x": 999.0, "max_seconds": 0.1}])
	for i: int in range(10):
		stuck.apply(level, DT)
	check(stuck.failed and stuck.error_message.contains("step 1"), "until_x fails after max_seconds.")
	var climb := RouteRunner.new([{"hold": ["move_up", "move_right"], "seconds": 0.1}, {"tap": "jump"}, {"hold": ["slide"], "seconds": 0.1}])
	climb.apply(level, DT)
	check(level.player.input_override.get("vertical") == -1.0 and level.player.input_override.get("direction") == 1.0, "move_up sets vertical -1.")
	for i: int in range(6):
		climb.apply(level, DT)
	check(level.action_override.get(&"jump") == true, "A jump tap is also an action press for reseats.")
	climb.apply(level, DT)
	check(level.player.input_override.get("slide_pressed") == true, "slide sets slide_pressed.")
	check(RouteRunner.new([{"hold": ["move_up"], "until_y": 100, "max_seconds": 1}]).error_message.is_empty(), "until_y is a valid stop condition.")
	var up := RouteRunner.new([{"hold": ["move_up"], "until_y": 50.0, "max_seconds": 1.0}])
	level.player.position.y = 80.0
	up.apply(level, DT)
	check(up.index == 0, "until_y waits while above the target is not reached.")
	level.player.position.y = 40.0
	up.apply(level, DT)
	check(up.done(), "until_y ends when y is at or above the target.")
	var down := RouteRunner.new([{"hold": ["move_down"], "until_y": 80.0, "max_seconds": 1.0}])
	level.player.position.y = 40.0
	down.apply(level, DT)
	check(down.index == 0 and level.player.input_override.get("vertical") == 1.0, "A descending route holds down until its target is reached.")
	level.player.position.y = 80.0
	down.apply(level, DT)
	check(down.done(), "A descending route ends at its target.")
	var stuck_down := RouteRunner.new([{"hold": ["move_down"], "until_y": 120.0, "max_seconds": 0.1}])
	for i: int in range(10):
		stuck_down.apply(level, DT)
	check(stuck_down.failed and stuck_down.error_message.contains("y=120"), "A descending route fails when its target cannot be reached.")
	check(not RouteRunner.new([{"dance": 1}]).error_message.is_empty(), "Unknown step kinds are rejected.")
	for bad: Dictionary in [
		{"hold": ["move_right"], "seconds": -1},
		{"hold": ["move_right"], "seconds": "2"},
		{"hold": ["move_right"], "until_x": 10, "max_seconds": 0},
		{"hold": ["move_right"], "seconds": 1, "until_x": 10, "max_seconds": 2},
		{"hold": ["jump"], "until_x": 10, "max_seconds": 1},
		{"hold": ["move_left", "move_right"], "until_x": 10, "max_seconds": 1},
		{"hold": ["jump"], "until_y": 10, "max_seconds": 1},
		{"hold": ["move_up", "move_down"], "until_y": 10, "max_seconds": 1},
		{"wait": -0.5},
		{"tap": "jump", "wait": 1},
	]:
		check(not RouteRunner.new([bad]).error_message.is_empty(), "Malformed step is rejected: %s" % bad)
	print("ROUTE_RUNNER_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
