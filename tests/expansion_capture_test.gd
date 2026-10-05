# godot_test_args: --fixed-fps 60
extends SceneTree

const LEVEL = preload("res://game/level.tscn")
const Runner = preload("res://game/route_runner.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var capture_script: Script = load("res://tests/expansion_capture.gd")
	var constants := capture_script.get_script_constant_map()
	check(constants.has("RouteInput"), "Capture input must run independently of screenshot waits.")
	if constants.has("RouteInput"):
		var level := LEVEL.instantiate()
		level.level_path = "res://levels/06-cooling-gallery.level"
		root.add_child(level)
		check(level.error_message.is_empty(), "The capture fixture loads: " + level.error_message)
		var driver: Node = constants["RouteInput"].new()
		driver.level = level
		driver.runner = Runner.new([{"hold": ["move_right"], "seconds": 1.0}])
		driver.process_physics_priority = -200
		root.add_child(driver)
		var start: Vector2 = level.player.position
		await create_timer(0.2).timeout
		check(driver.ticks >= 10, "Physics input continues while the capture coroutine waits.")
		check(level.player.position.x > start.x + 16, "The real player continues its route during capture work.")
		check(driver.finished_ticks == 0, "An active route has not entered its completion grace period.")
		await create_timer(1.0).timeout
		check(driver.finished_ticks > 0, "The driver keeps ticking after input exhaustion for bounded completion checks.")
		driver.queue_free()
		level.queue_free()
		await process_frame
	print("EXPANSION_CAPTURE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
