extends SceneTree

const LEVEL := preload("res://game/level.tscn")
const MAIN := preload("res://game/main.tscn")
var samples: Array[Dictionary] = []
var output := ""
var phase := ""
var started := 0
var current: Node


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Animation probe requires a rendered window; remove --headless.")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	if output.is_empty():
		push_error("Animation probe requires --output=<existing directory>.")
		quit(1)
		return
	run.call_deferred()


func record(delta: float) -> void:
	if phase.is_empty():
		return
	var player = current.player
	var sprite: AnimatedSprite2D = player.sprite
	samples.append({
		"phase": phase, "wall_us": Time.get_ticks_usec() - started,
		"delta": delta, "physics_frame": Engine.get_physics_frames(),
		"position": [player.position.x, player.position.y],
		"velocity": [player.velocity.x, player.velocity.y],
		"camera": [current.camera.get_screen_center_position().x, current.camera.get_screen_center_position().y],
		"clip": String(sprite.animation), "frame": sprite.frame,
		"progress": sprite.frame_progress, "playing": sprite.is_playing(),
		"locked": player.locked, "action": String(player.action),
		"climbing": player.motor.climbing, "hits": current.health.hits_taken,
		"respawns": current.respawns,
		"process_seconds": Performance.get_monitor(Performance.TIME_PROCESS),
		"physics_seconds": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),
		"texture_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
	})


func _process(delta: float) -> bool:
	record(delta)
	return false


func run() -> void:
	for hero: String in ["man", "woman"]:
		for action: String in ["run", "repair", "climb"]:
			current = LEVEL.instantiate()
			current.character = hero
			current.level_path = "res://levels/03-cable-jungle.level"
			root.add_child(current)
			if not current.error_message.is_empty():
				push_error(current.error_message)
				quit(1)
				return
			current.use_action_override = true
			current.player.use_override = true
			var at := Vector2(960, 416)
			var seconds := 1.25
			if action == "repair":
				at = Vector2(1344, 320)
				seconds = 1.95
			elif action == "climb":
				at = Vector2(4880, 416)
				seconds = 1.7
			current.player.respawn(at)
			await create_timer(0.2).timeout
			if action == "run":
				current.player.input_override = {"direction": 1.0}
			elif action == "repair":
				current.action_override = {"repair": true}
			else:
				current.player.input_override = {"vertical": -1.0}
			phase = hero + "-" + action
			started = Time.get_ticks_usec()
			DisplayServer.window_set_title("Animation probe: " + phase)
			await create_timer(seconds).timeout
			phase = ""
			current.queue_free()
			await process_frame
	var file := FileAccess.open(output.path_join("native-trace.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write animation probe trace: %s" % FileAccess.get_open_error())
		quit(1)
		return
	file.store_string(JSON.stringify(samples))
	file.close()
	for hero: String in ["man", "woman"]:
		var main := MAIN.instantiate()
		main.save_path = "user://animation-probe-unused.json"
		root.add_child(main)
		if not main.error_message.is_empty():
			push_error(main.error_message)
			quit(1)
			return
		main.save.character = hero
		main.open_help()
		main.help_view.next_page()
		DisplayServer.window_set_title("Animation probe: " + hero + " help")
		await create_timer(1.8).timeout
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(output.path_join(hero + "-help.png"))
		if error != OK:
			push_error("Cannot save help evidence: %s" % error)
			quit(1)
			return
		await create_timer(2.6).timeout
		main.queue_free()
		await process_frame
		await process_frame
	print("ANIMATION_PROBE_COMPLETE: %d rendered samples" % samples.size())
	quit()
