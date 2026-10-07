extends SceneTree

const Probe = preload("res://tests/background_perf_probe.gd")

var checks := 0
var failures := 0

class FakeLevel:
	extends Node
	var camera := Camera2D.new()


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var level := FakeLevel.new()
	root.add_child(level)
	level.camera.limit_left = 0
	level.camera.limit_top = 0
	level.camera.limit_right = 14016
	level.camera.limit_bottom = 448
	level.camera.zoom = Vector2(2, 2)
	var bounds: Dictionary = Probe.camera_sweep_bounds(level)
	check(bounds.get("half_extent", Vector2.ZERO) == Vector2(320, 180), "Camera bounds use zoom-adjusted half extent.")
	check(bounds["start"] == Vector2(320, 268), "Sweep starts at the effective lower-left camera center.")
	check(bounds["end"] == Vector2(13696, 180), "Sweep ends at the effective upper-right camera center.")
	level.queue_free()
	await process_frame
	print("BACKGROUND_PERF_PROBE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)
