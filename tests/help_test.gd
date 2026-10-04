extends SceneTree

const MAIN := preload("res://game/main.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var main := MAIN.instantiate()
	main.save_path = "user://help-test.json"
	root.add_child(main)
	await process_frame
	check(has_button(main.screen, "How to Play"), "Title exposes How to Play.")
	check(main.has_method("open_help"), "Help has a pause-safe entry point.")
	if main.has_method("open_help"):
		var title: Node = main.screen
		main.open_help()
		check(main.help_view != null and main.screen == title, "Title help preserves its return screen.")
		check(main.help_view.page_count() == 6, "Help pages cover controls and five work tasks.")
		var browser: Dictionary = main.mobile.menu_model()
		check(browser["screen"] == "help" and browser.has("help"), "Phone receives the same help model.")
		check(browser["help"]["controls"].size() == 9, "Phone controls include movement, tasks and pause.")
		main.close_help()
		check(main.screen == title and not paused, "Back from title help returns to title.")
		main.start_level("01")
		await process_frame
		var level: Node = main.screen
		main.toggle_pause()
		var elapsed: float = level.timer.elapsed
		var position: Vector2 = level.player.position
		var task_state: Array = level.tasks.completed_ids()
		check(has_button(main.pause_menu, "How to Play"), "Escape pause exposes How to Play.")
		main.open_help()
		check(paused and not main.pause_menu.visible and main.screen == level, "Help overlays, rather than replaces or resumes, the paused level.")
		main.mobile.enabled = true
		for page: int in range(1, 6):
			check(activate(main.mobile, main.mobile.menu_model(), "Next"), "Phone Next navigates the real help view.")
			browser = main.mobile.menu_model()
			var demo: Dictionary = browser["help"]["demo"]
			check(not demo["steps"].is_empty() and not demo["images"].is_empty(), "Phone task page carries a real looping hero/prop demo.")
			check(not browser["help"]["instructions"].is_empty(), "Phone has equivalent ordered task instructions.")
			check(main.help_view.demo.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Native help preserves pixel edges when it scales hero and prop art.")
			var native: Dictionary = main.help_view.demo.snapshot(0.0)
			var looped: Dictionary = main.help_view.demo.snapshot(main.help_view.demo.duration())
			check(native == looped, "Task demonstration loops predictably.")
			check(main.help_view.demo.snapshot(1.4) != native, "Task demonstration advances its existing hero frames or phase.")
			check(main.help_view.demo.snapshot(8.0, true) == native, "Reduced-motion demonstration is static, with instructions retained.")
			check(browser["help"]["id"] in ["repair", "fetch", "diagnose_repair", "reseat", "switch"], "Only the five existing tasks are taught.")
			await check_stable_demo_layout(main.help_view)
		main.route_runner = preload("res://game/route_runner.gd").new([{"wait": 0.1}])
		await create_timer(0.2).timeout
		check(level.timer.elapsed == elapsed and level.player.position == position and level.tasks.completed_ids() == task_state, "Time, position and task state remain intact during help.")
		check(main.route_runner.index == 0, "Help also pauses a live smoke route rather than advancing its inputs.")
		main.route_runner = null
		var event := InputEventAction.new()
		event.action = "pause"
		event.pressed = true
		main._unhandled_input(event)
		check(main.help_view == null and paused and main.pause_menu.visible and main.screen == level, "Escape returns to pause, never gameplay or a new level.")
		main.open_help()
		check(activate(main.mobile, main.mobile.menu_model(), "Back"), "Phone Back closes help.")
		check(paused and main.screen == level, "Back follows the same pause-safe path.")
		main.toggle_pause()
		check(not paused and main.screen == level, "Only Resume continues the original level.")
	main.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	if FileAccess.file_exists("user://help-test.json"):
		DirAccess.remove_absolute("user://help-test.json")
	print("HELP_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func has_button(source: Node, text: String) -> bool:
	for button: Button in source.find_children("*", "Button", true, false):
		if button.text == text:
			return true
	return false


func activate(bridge: Node, model: Dictionary, text: String) -> bool:
	for control: Dictionary in model["controls"]:
		if control.get("text") == text:
			return bridge.command({"type": "menu", "revision": model["revision"], "id": control["id"]})
	return false


func check_stable_demo_layout(view: Control) -> void:
	view.set_process(false)
	view.demo.set_process(false)
	var first: Array = []
	var seconds := 0.0
	for phase: Dictionary in view.demo.steps:
		view.demo.clock = seconds + 0.01
		view._process(0.0)
		for i: int in range(3):
			await process_frame
		var positions: Array = [view._column.global_position.y, view.demo.global_position.y]
		for button: Button in view.find_children("*", "Button", true, false):
			positions.append(button.global_position.y)
		if first.is_empty():
			first = positions
		else:
			check(positions == first, "Changing demo cue or completing the task must not move the title, demonstration or navigation.")
		seconds += phase["seconds"]


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
