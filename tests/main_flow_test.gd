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
	check(main.get_viewport().gui_get_focus_owner() != null, "The title screen focuses a button.")
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
	check(main.screen.level_path.ends_with("01-cold-aisle.level") and main.screen.character == "woman", "The level gets its file and character.")
	main.toggle_pause()
	check(paused and main.pause_menu.visible, "Pause stops the tree and shows the menu.")
	main.toggle_pause()
	check(not paused and not main.pause_menu.visible, "Pause again resumes.")
	main.screen.finished.emit({"elapsed": 40.0, "hits": 0, "respawns": 0, "stars": 3, "optional_done": 1, "optional_total": 1})
	await process_frame
	check(main.screen_name == "results", "Finishing a level opens results.")
	check(main.save.stars("01") == 3 and main.save.is_unlocked("02"), "Results are saved and unlock the next level.")
	check(main.screen.stars == 3, "Results show the earned stars.")
	var reloaded := preload("res://game/save_store.gd").new(SAVE_PATH)
	reloaded.load_data()
	check(reloaded.stars("01") == 3 and reloaded.character == "woman", "Progress is written to disk.")
	main.go_to("level_select")
	await process_frame
	check(main.screen_name == "level_select", "Results return to level select.")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	print("MAIN_FLOW_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
