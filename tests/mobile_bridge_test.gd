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
	check(not bridge.enabled, "Desktop does not enable the mobile interface.")
	bridge.enabled = true
	root.size = Vector2i(844, 390)
	main.audio.unlocked = false
	bridge.command({"type": "clear"})
	check(not main.audio.unlocked, "Lifecycle cleanup does not unlock audio without user input.")
	var model: Dictionary = bridge.menu_model()
	check(model["screen"] == "title", "Mobile model follows the real title screen.")
	check(activate(bridge, model, "Settings"), "Settings is reachable from touch.")
	await process_frame
	model = bridge.menu_model()
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "Phone menus fill the screen instead of letterboxing the 4:3 layout.")
	check(is_equal_approx(root.content_scale_factor, 1.25), "Phone menus are enlarged for short landscape screens.")
	check_rects(model)
	var slider: Dictionary = model["controls"].filter(func(c: Dictionary) -> bool: return c["kind"] == "slider")[0]
	var slider_node: HSlider = instance_from_id(int(slider["id"]))
	check(bridge.command({"type": "menu_focus", "revision": model["revision"], "id": slider["id"]}), "A focused browser twin can focus its in-game slider.")
	check(slider_node.has_focus(), "The in-game selection follows browser keyboard focus.")
	check(bridge.menu_model()["controls"].any(func(c: Dictionary) -> bool: return c["id"] == slider["id"] and c.get("focused", false)), "The menu model publishes the in-game focus for browser verification.")
	check(not bridge.command({"type": "menu_focus", "revision": model["revision"] - 1, "id": slider["id"]}), "A stale focus command cannot change the in-game selection.")
	check(bridge.command({"type": "menu", "revision": model["revision"], "id": slider["id"], "value": 0.25}), "Touch changes the real volume slider.")
	check(is_equal_approx(main.save.settings["music_volume"], 0.25), "Touch settings persist through the existing signal.")
	check(activate(bridge, model, "Back"), "Touch can leave Settings.")
	check(not activate(bridge, model, "Back"), "A stale menu command cannot activate the next screen.")
	await process_frame
	model = bridge.menu_model()
	check(model["summary"].contains("Tap Start") and not model["summary"].contains("Press any key"), "The in-game title speaks to touch players.")
	var start: Dictionary = model["controls"].filter(func(c: Dictionary) -> bool: return c.get("text") == "Start")[0]
	var start_node: Button = instance_from_id(int(start["id"]))
	check(bridge.command({"type": "menu_focus", "revision": model["revision"], "id": start["id"]}) and start_node.has_focus(), "A browser keyboard focus selects the matching in-game button.")
	check(activate(bridge, model, "Start"), "Touch can start character selection.")
	await process_frame
	check(activate(bridge, bridge.menu_model(), "Woman"), "Touch can choose a technician.")
	await process_frame
	model = bridge.menu_model()
	var play: Dictionary = model["controls"].filter(func(c: Dictionary) -> bool: return c.get("text", "").begins_with("01"))[0]
	check(bridge.command({"type": "menu", "revision": model["revision"], "id": play["id"]}), "Touch can start the first work order.")
	await process_frame
	main.screen.set_physics_process(false)
	main.screen.player.set_physics_process(false)
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "The phone camera expands instead of letterboxing the 4:3 view.")
	check(is_equal_approx(root.content_scale_factor, 1.0), "Gameplay keeps its full view while menus are enlarged.")
	check(not main.screen.hud.visible, "Mobile uses one safe area HUD instead of drawing a duplicate behind its overlay.")
	check(bridge.menu_model().get("slide_nearby") == false, "The open starting aisle does not need Slide.")
	main.screen.hud.set_prompt({"action": "repair", "intent": "hold", "text": "repair", "status": ""})
	var guidance: Dictionary = bridge.menu_model().get("prompt", {})
	check(guidance.get("action") == "repair" and guidance.get("description") == "Hold Repair to repair", "Bridge publishes one structured action and description.")
	bridge.command({"type": "action", "action": "repair", "down": true})
	main.screen.hud.set_prompt({"action": "jump", "intent": "press", "text": "reseat cable", "status": ""})
	check(bridge.input.held(&"repair"), "Changing guidance never clears touch input.")
	check(bridge.menu_model().get("prompt", {}).get("action") == "jump", "The next cable action reaches the browser without prose parsing.")
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
	check(bridge.menu_model().get("prompt", {}).get("action") == "", "Pause clears the published cue.")
	await process_frame
	model = bridge.menu_model()
	var resume: Dictionary = model["controls"].filter(func(c: Dictionary) -> bool: return c.get("text") == "Resume")[0]
	check(resume["rect"][3] > 0.1 and model["controls"].all(func(c: Dictionary) -> bool: return c["rect"][1] >= 0.0 and c["rect"][1] + c["rect"][3] <= 1.0), "The pause menu above a level is enlarged like other phone menus and stays on screen.")
	tap_twin(model, "How to Play")
	await process_frame
	check(main.help_view != null, "A tap on a pause menu twin reaches the enlarged in-game button.")
	if main.help_view != null:
		tap_twin(bridge.menu_model(), "Back")
		await process_frame
		check(main.help_view == null and main.pause_menu.visible, "A tap on a help twin above a level reaches the in-game button.")
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
	main.toggle_pause()
	main.open_help()
	main.screen.free()
	main.screen = null
	var retired_help: Dictionary = bridge.menu_model()
	check(retired_help.get("screen") == "help" and not retired_help.get("controls", []).is_empty(), "A retained help view does not dereference a retired level.")
	check(not retired_help.has("status") and not retired_help.has("prompt"), "Self-contained help does not publish live-level telemetry.")
	main.close_help()
	var retired_pause: Dictionary = bridge.menu_model()
	check(retired_pause.get("summary") == "Work order unavailable." and not retired_pause.has("status"), "An unavailable paused level returns a precise error rather than dereferencing it.")
	main.go_to("title")
	await process_frame
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
	level.level["solids"][Vector2i(5, 3)] = "tray"
	level.player.position = Vector2(3 * 32, 5 * 32)
	check(bridge.menu_model().get("slide_nearby") == true, "Slide is available on approach to a low tray without a tutorial prompt.")
	level.player.position.y -= 3 * 32
	check(bridge.menu_model().get("slide_nearby") == false, "A tray on another floor does not offer Slide.")
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
			level.step(1.0 / 60.0)
			check(bridge.menu_model()["prompt"]["action"] == "diagnose", "A marked rack requests Diagnose, not Repair.")
			touch_step(bridge, level, &"diagnose")
			level.step(0.9)
			level.step(1.0 / 60.0)
			check(rack.diagnosed, "Touch Diagnose prepares the rack.")
			check(bridge.menu_model()["prompt"]["action"] == "repair", "Finishing diagnosis switches the work control to Repair.")
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


# Taps the in-game control where the browser places its screen reader twin.
func tap_twin(model: Dictionary, text: String) -> void:
	var r: Array = model["controls"].filter(func(c: Dictionary) -> bool: return c.get("text") == text)[0]["rect"]
	var at := Vector2(r[0] + r[2] / 2, r[1] + r[3] / 2) * Vector2(root.size)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event)


func check_rects(model: Dictionary) -> void:
	var view: Vector2 = root.get_visible_rect().size
	for control: Dictionary in model["controls"]:
		var node: Control = instance_from_id(int(control["id"]))
		var expected: Rect2 = node.get_global_rect()
		var rect: Array = control.get("rect", [])
		var matches: bool = rect.size() == 4 and expected.size.x > 0.0 and expected.size.y > 0.0
		if matches:
			for i: int in range(4):
				var target: float = [expected.position.x / view.x, expected.position.y / view.y, expected.size.x / view.x, expected.size.y / view.y][i]
				matches = matches and absf(float(rect[i]) - target) < 0.0001
		check(matches, "%s publishes where it appears in the game so the screen reader copy can sit over it." % control["text"])


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
