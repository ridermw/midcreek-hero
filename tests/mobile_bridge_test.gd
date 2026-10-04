extends SceneTree

const MAIN := preload("res://game/main.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check_startup_error()
	var main := MAIN.instantiate()
	main.save_path = "user://mobile-test.json"
	root.add_child(main)
	await process_frame
	check(main.get("mobile") != null, "Main owns the mobile adapter.")
	if main.get("mobile") == null:
		main.queue_free()
		await process_frame
		await create_timer(0.3).timeout
		finish()
		return
	var bridge = main.mobile
	check(bridge.touch_prompt("Run: A / D or arrows. Pad: left stick") == "Run with Left and Right.", "Touch tutorial names movement controls.")
	check(bridge.touch_prompt("Low trays ahead: slide under them with C or Shift") == "Low trays ahead: slide under them with Slide", "Touch tutorial names Slide.")
	check(bridge.touch_prompt("Climb with W or Up, then step onto the catwalk") == "Climb with Up, then step onto the catwalk", "Touch tutorial names Up.")
	check(bridge.touch_prompt("Press Q to diagnose, then hold E to repair") == "Press Diagnose to diagnose, then hold Repair to repair", "Touch tutorial names both task controls.")
	check(not bridge.enabled, "Desktop does not enable the mobile interface.")
	bridge.enabled = true
	main.audio.unlocked = false
	bridge.command({"type": "clear"})
	check(not main.audio.unlocked, "Lifecycle cleanup does not unlock audio without user input.")
	var model: Dictionary = bridge.menu_model()
	check(model["screen"] == "title", "Mobile model follows the real title screen.")
	check(activate(bridge, model, "Settings"), "Settings is reachable from touch.")
	await process_frame
	model = bridge.menu_model()
	var slider: Dictionary = model["controls"].filter(func(c: Dictionary) -> bool: return c["kind"] == "slider")[0]
	check(bridge.command({"type": "menu", "revision": model["revision"], "id": slider["id"], "value": 0.25}), "Touch changes the real volume slider.")
	check(is_equal_approx(main.save.settings["music_volume"], 0.25), "Touch settings persist through the existing signal.")
	check(activate(bridge, model, "Back"), "Touch can leave Settings.")
	check(not activate(bridge, model, "Back"), "A stale menu command cannot activate the next screen.")
	await process_frame
	check(activate(bridge, bridge.menu_model(), "Start"), "Touch can start character selection.")
	await process_frame
	check(activate(bridge, bridge.menu_model(), "Woman"), "Touch can choose a technician.")
	await process_frame
	model = bridge.menu_model()
	var play: Dictionary = model["controls"].filter(func(c: Dictionary) -> bool: return c.get("text", "").begins_with("01"))[0]
	check(bridge.command({"type": "menu", "revision": model["revision"], "id": play["id"]}), "Touch can start the first work order.")
	await process_frame
	main.screen.set_physics_process(false)
	main.screen.player.set_physics_process(false)
	check(not main.screen.hud.prompt_label.visible, "Mobile uses the readable browser prompt instead of a duplicate keyboard prompt.")
	for action: String in ["move_left", "move_right", "move_up", "move_down", "jump", "slide", "repair", "diagnose"]:
		bridge.command({"type": "action", "action": action, "down": true})
	bridge.input.advance()
	check(main.screen.player.read_input()["jump_pressed"], "Touch jump reaches the player.")
	check(main.screen._action_pressed(&"jump"), "The same touch jump reaches cable sequences.")
	check(main.screen._action_held(&"repair") and main.screen._action_pressed(&"diagnose"), "Repair and diagnose reach tasks.")
	bridge.input.clear()
	bridge.command({"type": "action", "action": "move_up", "down": true})
	bridge.input.advance()
	check(main.screen.player.read_input()["vertical"] == -1.0, "Touch up climbs ladders.")
	Input.action_press(&"move_right")
	bridge.command({"type": "clear"})
	check(main.screen.player.read_input()["direction"] == 1.0, "Clearing touch does not release keyboard input.")
	Input.action_release(&"move_right")
	bridge.command({"type": "pause"})
	check(paused and not bridge.input.held(&"move_up"), "Pause releases movement.")
	model = bridge.menu_model()
	check(activate(bridge, model, "Restart work order"), "Touch can restart from pause.")
	await process_frame
	bridge.command({"type": "suspend"})
	bridge.command({"type": "suspend"})
	check(paused, "Repeated orientation or focus suspension never resumes play.")
	check(activate(bridge, bridge.menu_model(), "Resume"), "Touch can resume after suspension.")
	check(not paused, "Resume restores gameplay.")
	main.screen.finished.emit({"elapsed": 40.0, "hits": 0, "respawns": 0, "stars": 3, "optional_done": 1, "optional_total": 1})
	await process_frame
	model = bridge.menu_model()
	check(model["screen"] == "results" and model["summary"].contains("3 stars"), "Mobile results include earned stars.")
	check(activate(bridge, model, "Retry"), "Touch can retry from results.")
	await process_frame
	bridge.command({"type": "pause"})
	check(activate(bridge, bridge.menu_model(), "Quit to level select"), "Touch can quit to work orders.")
	await process_frame
	await exercise_tasks(main, bridge)
	main.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	DirAccess.remove_absolute("user://mobile-test.json")
	finish()


func check_startup_error() -> void:
	var failed_main := MAIN.instantiate()
	failed_main.error_message = "Missing animation manifest."
	var bridge := preload("res://game/mobile_bridge.gd").new()
	bridge.main = failed_main
	root.add_child(bridge)
	check(bridge.menu_model() == {
		"screen": "", "paused": false, "revision": 0,
		"controls": [], "summary": "Missing animation manifest.",
	}, "A startup failure remains visible in the mobile menu without a screen.")
	bridge.free()
	failed_main.free()


func exercise_tasks(main: Node, bridge: Node) -> void:
	main._level_files["01"] = "res://tests/fixtures/cable_jungle.level"
	main.start_level("01")
	await process_frame
	var level: Node = main.screen
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	var port: Node = level.entities["ports"][0]
	level.player.position = port.position
	touch_step(bridge, level, &"repair")
	check(port.state == "active", "Touch Repair starts a cable sequence.")
	for action: StringName in port.sequence_for(port.task_id):
		touch_step(bridge, level, action)
	check(port.done, "Touch completes every cable sequence button.")
	main._level_files["01"] = "res://tests/fixtures/hot_aisle.level"
	main.start_level("01")
	await process_frame
	level = main.screen
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	var part: Node = level.entities["parts"][0]
	level.player.position = part.position
	level.step(1.0 / 60.0)
	check(level.carried_part == part.task_id, "Movement pickup remains automatic.")
	for rack: Node in level.entities["racks"]:
		level.player.position = rack.position
		if rack.kind == "diagnose_repair":
			touch_step(bridge, level, &"diagnose")
			level.step(0.9)
			check(rack.diagnosed, "Touch Diagnose prepares the rack.")
		bridge.command({"type": "action", "action": "repair", "down": true})
		for i: int in range(150):
			bridge.input.advance()
			level.step(1.0 / 60.0)
		bridge.command({"type": "clear"})
		check(rack.done, "Touch hold repairs or delivers to the rack.")
	main._level_files["01"] = "res://tests/fixtures/power_room.level"
	main.start_level("01")
	await process_frame
	level = main.screen
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	for panel: Node in level.entities["switches"]:
		level.player.position = panel.position
		touch_step(bridge, level, &"repair")
		check(panel.on, "Touch Repair activates the ordered switch.")


func touch_step(bridge: Node, level: Node, action: StringName) -> void:
	bridge.command({"type": "action", "action": action, "down": true})
	bridge.command({"type": "action", "action": action, "down": false})
	bridge.input.advance()
	level.step(1.0 / 60.0)
	bridge.input.advance()
	level.step(1.0 / 60.0)


func activate(bridge: Node, model: Dictionary, text: String) -> bool:
	for control: Dictionary in model["controls"]:
		if control.get("text") == text:
			return bridge.command({"type": "menu", "revision": model["revision"], "id": control["id"]})
	return false


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)


func finish() -> void:
	print("MOBILE_BRIDGE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
