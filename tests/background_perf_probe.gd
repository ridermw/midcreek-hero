extends SceneTree

const LEVEL := preload("res://game/level.tscn")
const LEVELS := ["01-cold-aisle", "09-loading-yard", "14-facility-approach"]
const WARMUP_FRAMES := 120
const SAMPLE_FRAMES := 600
const VIEWPORT_SIZE := Vector2i(1280, 720)

var output := ""


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Background performance probe requires a rendered window; remove --headless.")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if output.is_empty():
		push_error("Background performance probe requires --output=<json path>.")
		quit(1)
		return
	run.call_deferred()


func run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	var results: Array[Dictionary] = []
	for slug: String in LEVELS:
		var level := LEVEL.instantiate()
		level.level_path = "res://levels/%s.level" % slug
		root.add_child(level)
		if not level.error_message.is_empty():
			push_error(level.error_message)
			quit(1)
			return
		level.set_physics_process(false)
		level.player.set_physics_process(false)
		level.camera.make_current()
		await process_frame
		results.append(await measure_level(slug, level))
		level.queue_free()
		await process_frame
	var payload := {
		"schema": "midcreek-background-perf-v1",
		"method": {
			"renderer": "native rendered Godot",
			"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
			"fixed_fps": 60,
			"warmup_frames": WARMUP_FRAMES,
			"sample_frames": SAMPLE_FRAMES,
			"levels": LEVELS,
			"host_note": "This host renders real time at about 33 Hz, so measurements are host-specific desktop evidence.",
			"browser_note": "Exported desktop browser measurement is blocked on this host because headless Edge uses software rendering too slow to measure.",
		},
		"results": results,
	}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write background performance output: " + output)
		quit(1)
		return
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	print("BACKGROUND_PERF_PROBE_COMPLETE: %d levels, 0 failures" % results.size())
	quit(0)


func measure_level(slug: String, level: Node) -> Dictionary:
	var bounds := camera_sweep_bounds(level)
	for frame: int in range(WARMUP_FRAMES):
		move_camera(level, bounds, float(frame) / float(maxi(WARMUP_FRAMES - 1, 1)))
		await process_frame
	var process_ms: Array[float] = []
	var draw_calls: Array[float] = []
	var texture_bytes: Array[float] = []
	var started := Time.get_ticks_usec()
	for frame: int in range(SAMPLE_FRAMES):
		move_camera(level, bounds, float(frame) / float(maxi(SAMPLE_FRAMES - 1, 1)))
		await process_frame
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		texture_bytes.append(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var wall_seconds := float(Time.get_ticks_usec() - started) / 1000000.0
	return {
		"level": slug,
		"camera": {
			"from": [bounds["start"].x, bounds["start"].y],
			"to": [bounds["end"].x, bounds["end"].y],
		},
		"process_ms_mean": average(process_ms),
		"process_ms_p95": percentile(process_ms, 0.95),
		"draw_calls_mean": average(draw_calls),
		"draw_calls_p95": percentile(draw_calls, 0.95),
		"texture_bytes_mean": average(texture_bytes),
		"texture_bytes_p95": percentile(texture_bytes, 0.95),
		"wall_seconds": wall_seconds,
		"real_time_fps": float(SAMPLE_FRAMES) / maxf(wall_seconds, 0.001),
	}


func camera_sweep_bounds(level: Node) -> Dictionary:
	var half := Vector2(VIEWPORT_SIZE) * 0.5
	var min_x: float = minf(float(level.camera.limit_left) + half.x, float(level.camera.limit_right) - half.x)
	var max_x: float = maxf(float(level.camera.limit_left) + half.x, float(level.camera.limit_right) - half.x)
	var top_y: float = minf(float(level.camera.limit_top) + half.y, float(level.camera.limit_bottom) - half.y)
	var bottom_y: float = maxf(float(level.camera.limit_top) + half.y, float(level.camera.limit_bottom) - half.y)
	return {"start": Vector2(min_x, bottom_y), "end": Vector2(max_x, top_y)}


func move_camera(level: Node, bounds: Dictionary, t: float) -> void:
	var position: Vector2 = bounds["start"].lerp(bounds["end"], t)
	level.camera.position = position
	level.player.position = position


func average(values: Array[float]) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func percentile(values: Array[float], fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(ceili(fraction * float(sorted.size())) - 1, 0, sorted.size() - 1)
	return sorted[index]
