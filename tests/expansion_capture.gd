extends SceneTree

const LEVEL = preload("res://game/level.tscn")
const Runner = preload("res://game/route_runner.gd")


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
		var captured := -1
		for frame: int in range(18000):
			runner.apply(level, 1.0 / 60.0)
			await physics_frame
			if frame % 600 == 0:
				print("CAPTURE_PROGRESS %s %s frame=%d step=%d position=%s" % [slug, hero, frame, runner.index, level.player.position])
			var count: int = level.tasks.completed_ids().size()
			if count != captured:
				captured = count
				await RenderingServer.frame_post_draw
				var path := directory.path_join("%s-%s-stage%d.png" % [slug, hero, count])
				if root.get_texture().get_image().save_png(path) != OK:
					printerr("Cannot write capture: " + path)
					quit(1)
					return
			if level.completed or runner.failed:
				break
		if not level.completed or runner.failed or level.health.hits_taken != 0 or level.respawns != 0:
			printerr("Rendered route failed: %s %s %s" % [slug, hero, runner.error_message])
			quit(1)
			return
		print("EXPANSION_CAPTURE %s %s elapsed=%.2f hits=0 respawns=0" % [slug, hero, level.timer.elapsed])
		level.queue_free()
		await process_frame
	quit(0)
