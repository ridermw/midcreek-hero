extends SceneTree

const MAIN := preload("res://game/main.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var main := MAIN.instantiate()
	main.save_path = "user://test-animation-probe.json"
	root.add_child(main)
	await process_frame
	var available := main.has_method("animation_probe_state") and main.has_method("wants_animation_probe")
	check(available, "A gated read-only animation probe is available.")
	if available:
		check(not main.animation_probe_enabled, "Ordinary launches do not publish probe state.")
		for query: String in ["", "?route=03", "?animation_probe=0", "?other_animation_probe=1"]:
			check(not main.wants_animation_probe(query, true), "Only explicit probe requests enable it: " + query)
		check(main.wants_animation_probe("?route=03&animation_probe=1", true), "A debug build accepts an explicit probe request.")
		check(not main.wants_animation_probe("?animation_probe=1", false), "Release builds ignore probe requests.")
		var menu: Dictionary = main.animation_probe_state()
		check(menu["screen"] == "title" and not menu.has("position"), "Menu snapshots do not invent a player.")
		for hero: String in ["man", "woman"]:
			main.save.character = hero
			main.start_level("03")
			await process_frame
			var level = main.screen
			level.set_physics_process(false)
			level.player.set_physics_process(false)
			level.player.use_override = true
			level.player.input_override = {"jump_pressed": true, "direction": 0.4}
			var position: Vector2 = level.player.position
			var before: Dictionary = level.player.input_override.duplicate()
			var state: Dictionary = main.animation_probe_state()
			check(state["character"] == hero and state["level_id"] == "03", "The snapshot identifies the actual level and hero.")
			check(state["position"] == [position.x, position.y], "The snapshot reports the real player position.")
			check(state["clip"] == String(level.player.sprite.animation), "The snapshot reports the actual animation clip.")
			check(state["frame"] == level.player.sprite.frame and state["playback_speed"] == level.player.sprite.get_playing_speed(), "The snapshot reports the current phase and playback speed.")
			check(
				state.get("physics_frame") == Engine.get_physics_frames()
				and state.get("elapsed") == level.timer.elapsed
				and state.get("facing_left") == level.player.sprite.flip_h,
				"The snapshot includes actual timing and facing for repeatable browser input.",
			)
			check(JSON.parse_string(JSON.stringify(state)) is Dictionary, "Probe data is serializable without engine objects.")
			state["position"][0] += 1000.0
			check(level.player.position == position and level.player.input_override == before, "Reading or editing a snapshot does not move the player or consume input.")
			main.toggle_pause()
			check(main.animation_probe_state()["paused"], "The probe reports pause state.")
			main.toggle_pause()
		main.go_to("title")
	main.queue_free()
	for i in range(4):
		await process_frame
	await create_timer(0.25).timeout
	print("ANIMATION_PROBE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
