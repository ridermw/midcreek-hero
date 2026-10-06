extends SceneTree

const LEVEL := preload("res://game/level.tscn")
const Runner := preload("res://game/route_runner.gd")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var directory := OS.get_environment("CAPTURE_DIR")
	if directory.is_empty() or OS.has_feature("headless"):
		printerr("Liquid capture requires a rendered viewport and CAPTURE_DIR.")
		quit(1)
		return
	for hero: String in ["man", "woman"]:
		var level := LEVEL.instantiate()
		level.character = hero
		level.level_path = "res://tests/fixtures/liquid.level"
		root.add_child(level)
		if not level.error_message.is_empty():
			printerr(level.error_message)
			quit(1)
			return
		var runner := Runner.new([{"hold": ["move_right"], "until_x": 360, "max_seconds": 4}])
		var captured := false
		for frame: int in range(360):
			if not level.player.dead and level.respawns == 0:
				runner.apply(level, 1.0 / 60.0)
			await physics_frame
			if level.player.dead and not captured:
				await RenderingServer.frame_post_draw
				var error := root.get_texture().get_image().save_png(directory.path_join("liquid-%s-native.png" % hero))
				if error != OK:
					printerr("Screenshot write failed: " + str(error))
					quit(1)
					return
				captured = true
			if level.respawns == 1:
				break
		if not captured or level.respawns != 1:
			printerr("Rendered contact did not recover exactly once: " + hero)
			quit(1)
			return
		level.queue_free()
		await process_frame
	print("LIQUID_CAPTURE_COMPLETE: both heroes captured and recovered.")
	quit(0)
