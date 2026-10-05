extends SceneTree

const LEVEL = preload("res://game/level.tscn")
const Runner = preload("res://game/route_runner.gd")

class RouteInput:
	extends Node
	var level: Node
	var runner: RefCounted
	var ticks := 0
	var finished_ticks := 0

	func _physics_process(delta: float) -> void:
		ticks += 1
		finished_ticks = finished_ticks + 1 if runner.done() else 0
		if is_instance_valid(level) and not level.completed:
			runner.apply(level, delta)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var directory := OS.get_environment("CAPTURE_DIR")
	if directory.is_empty() or OS.has_feature("headless"):
		printerr("Expansion capture requires a rendered viewport and CAPTURE_DIR.")
		quit(1)
		return
	var slug := OS.get_environment("CAPTURE_LEVEL")
	if slug.is_empty():
		slug = "06-cooling-gallery"
	var steps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/routes/" + slug + ".route.json"))
	for hero: String in ["man", "woman"]:
		var level := LEVEL.instantiate()
		level.character = hero
		level.level_path = "res://levels/" + slug + ".level"
		root.add_child(level)
		if not level.error_message.is_empty():
			printerr(level.error_message)
			quit(1)
			return
		var runner := Runner.new(steps)
		var driver := RouteInput.new()
		driver.level = level
		driver.runner = runner
		driver.process_physics_priority = -200
		root.add_child(driver)
		var captured := -1
		var partial_fire_captured := false
		for frame: int in range(18000):
			await physics_frame
			if frame % 600 == 0:
				print("CAPTURE_PROGRESS %s %s frame=%d step=%d position=%s elapsed=%.2f tasks=%s" % [slug, hero, frame, runner.index, level.player.position, level.timer.elapsed, level.tasks.completed_ids()])
			var count: int = level.tasks.completed_ids().size()
			var capture_tag := ""
			var partial_station: Node2D
			if count != captured:
				captured = count
				capture_tag = "stage%d" % count
			if capture_tag.is_empty() and not partial_fire_captured:
				for station in level.entities["work"]:
					if station.order.definition["type"] == "extinguish_fire" and station.order.unit.intensity <= 1.5 and station.order.unit.intensity > 0.0:
						partial_fire_captured = true
						capture_tag = "partial-fire"
						partial_station = station
						break
			if not capture_tag.is_empty():
				await RenderingServer.frame_post_draw
				if capture_tag == "partial-fire" and (partial_station.order.unit.intensity <= 0.0 or partial_station.order.unit.intensity > 1.5):
					partial_fire_captured = false
					continue
				var path := directory.path_join("%s-%s-%s.png" % [slug, hero, capture_tag])
				if root.get_texture().get_image().save_png(path) != OK:
					printerr("Cannot write capture: " + path)
					quit(1)
					return
			if level.completed or runner.failed or driver.finished_ticks >= 120:
				break
		if not level.completed or runner.failed or level.health.hits_taken != 0 or level.respawns != 0:
			printerr("Rendered route failed: %s %s %s" % [slug, hero, runner.error_message])
			for station in level.entities["work"]:
				printerr("%s: %s" % [station.order.definition["id"], station.capture_state()])
			quit(1)
			return
		print("EXPANSION_CAPTURE %s %s elapsed=%.2f hits=0 respawns=0" % [slug, hero, level.timer.elapsed])
		driver.queue_free()
		level.queue_free()
		await process_frame
	quit(0)
