# godot_test_args: --fixed-fps 60
extends SceneTree

const LEVEL = preload("res://game/level.tscn")
const Runner = preload("res://game/route_runner.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for hero: String in ["man", "woman"]:
		var level := LEVEL.instantiate()
		level.character = hero
		level.level_path = "res://levels/09-loading-yard.level"
		root.add_child(level)
		check(level.error_message.is_empty(), "Loading Yard loads for " + hero)
		var bypass := Runner.new([
			{"hold": ["move_right"], "until_x": 400, "max_seconds": 5},
			{"wait": 0.35},
			{"hold": ["move_up"], "until_y": 460, "max_seconds": 5},
			{"hold": ["move_up", "move_right"], "seconds": 0.45},
			{"hold": ["move_right"], "until_x": 816, "max_seconds": 5},
			{"hold": ["move_right", "jump"], "seconds": 0.45},
			{"hold": ["move_right"], "until_x": 1570, "max_seconds": 6},
		])
		for frame: int in range(1200):
			bypass.apply(level, 1.0 / 60.0)
			await physics_frame
			if level.respawns > 0 or bypass.done() or bypass.failed:
				break
		check(not bypass.failed, hero + ": bypass probe reaches a defined outcome: " + bypass.error_message)
		check(level.respawns == 1 and level.checkpoints.index < 2, hero + ": undrained trench cannot latch an unrecoverable far checkpoint.")
		check(not level.tasks.is_done("trench"), "The probe did not operate the drain.")
		level.queue_free()
		await process_frame
	print("LOADING_YARD_ACCESS_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
