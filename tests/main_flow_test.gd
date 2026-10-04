extends SceneTree

const MAIN_SCENE := preload("res://game/main.tscn")
const SAVE_PATH := "user://test-main-save.json"

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	var main := MAIN_SCENE.instantiate()
	main.save_path = SAVE_PATH
	root.add_child(main)
	await process_frame
	check(InputMap.has_action(&"jump") and InputMap.has_action(&"pause"), "main installs input actions.")
	check(main.screen_name == "title", "The game starts on the title screen.")
	check(main.audio != null and main.audio.get_parent() == main, "main owns one audio director.")
	check(main.music_name() == "title", "The title screen asks for title music.")
	check(main.get_viewport().gui_get_focus_owner() != null, "The title screen focuses a button.")
	check(main.screen.find_children("Settings", "Button", true, false).size() == 1, "The title screen has a Settings button.")
	main.go_to("settings")
	await process_frame
	check(main.screen_name == "settings" and main.screen.find_children("*", "HSlider", true, false).size() == 2, "Settings shows 2 volume sliders.")
	main.set_volume("music_volume", 0.3)
	main.set_volume("sfx_volume", 0.6)
	check(is_equal_approx(float(main.save.settings["music_volume"]), 0.3), "The music volume is saved.")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.3), "The music bus follows the slider.")
	check(main.route_from_query("?route=03") == "03" and main.route_from_query("?route=9") == "" and main.route_from_query("") == "", "Smoke mode parses ?route=0N.")
	check(main.route_from_args(["--route=02"]) == "02" and main.route_from_args(["--x"]) == "", "Smoke mode parses --route=0N.")
	main.go_to("character_select")
	await process_frame
	check(main.screen_name == "character_select", "Character select opens.")
	main.choose_character("woman")
	await process_frame
	check(main.save.character == "woman" and main.screen_name == "level_select", "Choosing a character opens level select.")
	var ids: Array[String] = main.level_ids()
	check(ids.size() >= 1 and ids[0] == "01" and not "00" in ids, "Level select lists shipped levels only.")
	check(main.level_button("01") != null and not main.level_button("01").disabled, "Level 01 is playable.")
	if main.level_button("02") != null:
		check(main.level_button("02").disabled, "Locked levels are disabled.")
	main.start_level("01")
	await process_frame
	check(main.screen_name == "level", "Starting a level opens it.")
	check(main.music_name() == "level1", "The level asks for its own music.")
	main.screen.sound.emit("jump")
	check(main.last_sfx == "jump", "Level sounds reach the audio director.")
	check(main.screen.level_path.ends_with("01-cold-aisle.level") and main.screen.character == "woman", "The level gets its file and character.")
	main.toggle_pause()
	check(paused and main.pause_menu.visible, "Pause stops the tree and shows the menu.")
	main.toggle_pause()
	check(not paused and not main.pause_menu.visible, "Pause again resumes.")
	var pause_buttons: Array[Node] = main.pause_menu.find_children("*", "Button", true, false)
	check(pause_buttons.size() == 3, "The pause menu has three actions.")
	for button: Button in pause_buttons:
		main.toggle_pause()
		main.last_sfx = ""
		button.pressed.emit()
		check(main.last_sfx == "menu_select", "Pause action plays selection audio: " + button.text)
		await process_frame
		check(not paused, "Pause action resumes the tree: " + button.text)
		if main.screen_name != "level":
			main.start_level("01")
			await process_frame
	main.screen.finished.emit({"elapsed": 40.0, "hits": 0, "respawns": 0, "stars": 3, "optional_done": 1, "optional_total": 1})
	await process_frame
	check(main.screen_name == "results", "Finishing a level opens results.")
	check(main.music_name() == "results", "Results ask for results music.")
	check(main.save.stars("01") == 3 and main.save.is_unlocked("02"), "Results are saved and unlock the next level.")
	check(main.screen.stars == 3, "Results show the earned stars.")
	var reloaded := preload("res://game/save_store.gd").new(SAVE_PATH)
	reloaded.load_data()
	check(reloaded.stars("01") == 3 and reloaded.character == "woman", "Progress is written to disk.")
	main.go_to("level_select")
	await process_frame
	check(main.screen_name == "level_select", "Results return to level select.")
	main.start_smoke("01")
	await process_frame
	check(main.screen_name == "level" and main.route_runner != null, "Smoke mode starts the level with its route.")
	main.go_to("level_select")
	await process_frame
	check(main.route_runner == null, "Leaving the level stops the route.")
	var reloaded_settings := preload("res://game/save_store.gd").new(SAVE_PATH)
	reloaded_settings.load_data()
	check(is_equal_approx(float(reloaded_settings.settings["sfx_volume"]), 0.6), "Volume settings persist.")
	main.queue_free()
	for i: int in range(4):
		await process_frame
	# The audio server releases stopped playbacks on its own thread.
	await create_timer(0.25).timeout
	DirAccess.remove_absolute(SAVE_PATH)
	print("MAIN_FLOW_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
