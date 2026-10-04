extends SceneTree

const MAIN := preload("res://game/main.tscn")
const PATH := "user://guidance-settings-test.json"
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	var main := MAIN.instantiate()
	main.save_path = PATH
	root.add_child(main)
	await process_frame
	check(main.has_method("control_display"), "Main resolves the saved display preference.")
	if main.has_method("control_display"):
		check(main.control_display() == "keyboard", "Nonphones default to keyboard.")
		main.mobile.enabled = true
		check(main.control_display() == "touch", "Detected phones default to touch.")
		check(not main.save.settings.has("control_display"), "Detecting a default does not fabricate a saved choice.")
		main.go_to("settings")
		await process_frame
		for display: String in ["Keyboard", "Gamepad", "Touch"]:
			var found := false
			for button: Button in main.screen.find_children("*", "Button", true, false):
				if button.text.begins_with(display):
					button.pressed.emit()
					found = true
					break
			check(found and main.control_display() == display.to_lower(), "Settings selects " + display)
		main.set_control_display("gamepad")
		main.mobile.enabled = false
		Input.action_press("repair")
		check(main.control_display() == "gamepad" and Input.is_action_pressed("repair"), "Display choice never switches with, or blocks, real input.")
		Input.action_release("repair")
		main.save.path = "user://missing-guidance-directory/save.json"
		main.set_control_display("keyboard")
		check(not main.notice_message.is_empty(), "Failed preference save has a visible warning.")
		check(main.notice_label.visible and main.notice_label.text == main.notice_message, "Desktop shows the save warning.")
		check(main.mobile.menu_model()["summary"].contains(main.notice_message), "Phone shows the same save warning.")
		main.notice_message = ""
		main.set_volume("music_volume", 0.5)
		check(not main.notice_message.is_empty(), "Related volume setter also reports write failure.")
		main.save.path = PATH
		main.set_volume("music_volume", 0.6)
		check(main.notice_message.is_empty() and not main.notice_label.visible, "A successful retry clears the stale save-failure banner.")
		check(not main.mobile.menu_model()["summary"].contains("Could not save"), "Phone also clears the recovered save failure.")
		var revision: int = main.mobile.revision
		main.set_volume("music_volume", 0.7)
		check(main.mobile.revision == revision, "Normal successful volume changes do not recreate the mobile menu.")
	main.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string('{"version":1,"levels":{"01":{"stars":2}},"settings":{"control_display":"invalid"}}')
	file.close()
	main = MAIN.instantiate()
	main.save_path = PATH
	root.add_child(main)
	await process_frame
	check(main.notice_label.visible and not main.notice_message.is_empty() and main.save.stars("01") == 2, "Startup cosmetic recovery warning is visible until the repaired save is written.")
	main.set_control_display("keyboard")
	check(main.notice_message.is_empty() and not main.notice_label.visible, "A successful corrected settings write intentionally clears the startup recovery warning.")
	main.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	print("GUIDANCE_SETTINGS_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
