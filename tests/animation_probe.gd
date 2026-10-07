extends SceneTree

const LEVEL := preload("res://game/level.tscn")
const MAIN := preload("res://game/main.tscn")
const ACTIONS := ["walk", "run", "repair", "climb", "descend", "climb-turn", "idle-run", "run-idle", "idle-diagnose", "diagnose-idle"]
var samples: Array[Dictionary] = []
var output := ""
var phase := ""
var started := 0
var current: Node
var only: PackedStringArray = []
var skip_help := false


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Animation probe requires a rendered window; remove --headless.")
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--actions="):
			var parsed := parse_actions(arg.trim_prefix("--actions="))
			if not parsed["ok"]:
				push_error(parsed["error"])
				quit(1)
				return
			only = parsed["actions"]
		elif arg == "--skip-help":
			skip_help = true
	if output.is_empty():
		push_error("Animation probe requires --output=<existing directory>.")
		quit(1)
		return
	run.call_deferred()


static func parse_actions(value: String) -> Dictionary:
	var selected := value.split(",", false)
	for action: String in selected:
		if not ACTIONS.has(action):
			return {
				"ok": false,
				"error": "Unknown animation probe action '%s'. Expected one of: %s" % [action, ", ".join(ACTIONS)],
				"actions": PackedStringArray(),
			}
	return {"ok": true, "error": "", "actions": selected}


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
		"flip": sprite.flip_h,
		"progress": sprite.frame_progress, "playing": sprite.is_playing(),
		"playback_speed": sprite.get_playing_speed(),
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
		for action: String in ACTIONS:
			if not only.is_empty() and not only.has(action):
				continue
			if action in ["idle-run", "run-idle", "idle-diagnose", "diagnose-idle"]:
				if not await transition(hero, action):
					return
				continue
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
			elif action == "descend":
				at = Vector2(4880, 256)
				seconds = 1.3
			elif action == "climb-turn":
				at = Vector2(4880, 352)
			current.player.respawn(at)
			await create_timer(0.2).timeout
			if action == "walk":
				current.player.input_override = {"direction": 0.4}
			elif action == "run":
				current.player.input_override = {"direction": 1.0}
			elif action == "repair":
				current.action_override = {"repair": true}
			elif action in ["climb", "climb-turn"]:
				current.player.input_override = {"vertical": -1.0}
			else:
				current.player.input_override = {"vertical": 1.0}
			phase = hero + "-" + action
			started = Time.get_ticks_usec()
			DisplayServer.window_set_title("Animation probe: " + phase)
			if action == "climb-turn":
				await create_timer(0.5).timeout
				current.player.input_override = {}
				await create_timer(0.3).timeout
				current.player.input_override = {"vertical": 1.0}
				await create_timer(0.5).timeout
			else:
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
	if skip_help:
		print("ANIMATION_PROBE_COMPLETE: %d rendered samples" % samples.size())
		quit()
		return
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


# Records one clip change: idle and run in Level 3, idle and diagnose at a Level 2 rack.
func transition(hero: String, action: String) -> bool:
	var diagnose := action.contains("diagnose")
	current = LEVEL.instantiate()
	current.character = hero
	current.level_path = "res://levels/02-hot-aisle.level" if diagnose else "res://levels/03-cable-jungle.level"
	root.add_child(current)
	if not current.error_message.is_empty():
		push_error(current.error_message)
		quit(1)
		return false
	current.use_action_override = true
	current.player.use_override = true
	var at := Vector2(960, 416)
	if diagnose:
		var racks: Array = current.entities["racks"].filter(func(r) -> bool: return r.kind == "diagnose_repair")
		if racks.is_empty():
			push_error("Level 2 has no diagnose rack for the probe.")
			quit(1)
			return false
		at = racks[0].position
	current.player.respawn(at)
	await create_timer(0.3).timeout
	if action == "run-idle":
		current.player.input_override = {"direction": 1.0}
		await create_timer(0.8).timeout
	phase = hero + "-" + action
	started = Time.get_ticks_usec()
	DisplayServer.window_set_title("Animation probe: " + phase)
	if action == "diagnose-idle":
		current.action_override = {"diagnose": true}
		await create_timer(0.05).timeout
		current.action_override = {}
		await create_timer(1.6).timeout
	else:
		await create_timer(0.4).timeout
		if action == "idle-run":
			current.player.input_override = {"direction": 1.0}
		elif action == "run-idle":
			current.player.input_override = {}
		else:
			current.action_override = {"diagnose": true}
			await create_timer(0.05).timeout
			current.action_override = {}
		await create_timer(1.2).timeout
	phase = ""
	current.queue_free()
	await process_frame
	return true
