extends SceneTree

const SaveStore = preload("res://game/save_store.gd")
const PATH := "user://test-save.json"

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func clear() -> void:
	for path: String in [PATH, "user://test-save.corrupt.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func run() -> void:
	clear()
	var store := SaveStore.new(PATH)
	store.load_data()
	check(store.is_unlocked("01") and not store.is_unlocked("02"), "Only level 01 starts unlocked.")
	check(store.character == "man" and store.stars("01") == 0, "Defaults are empty.")
	store.record("01", 2, 140.0, 1)
	check(store.stars("01") == 2 and store.best_seconds("01") == 140.0, "record stores stars and time.")
	check(store.is_unlocked("02"), "Finishing a level unlocks the next one.")
	store.record("01", 1, 150.0, 0)
	check(
		store.stars("01") == 2 and store.best_seconds("01") == 140.0 and store.best_optional("01") == 1,
		"record keeps the best values.",
	)
	store.record("01", 3, 120.0, 2)
	check(store.stars("01") == 3 and store.best_seconds("01") == 120.0 and store.best_optional("01") == 2, "record improves values.")
	store.character = "woman"
	store.settings["music_volume"] = 0.4
	check(store.save(), "save writes the file.")
	var loaded := SaveStore.new(PATH)
	loaded.load_data()
	check(loaded.stars("01") == 3 and loaded.is_unlocked("02"), "load restores progress.")
	check(loaded.character == "woman" and is_equal_approx(float(loaded.settings["music_volume"]), 0.4), "load restores character and settings.")
	var partial_file := FileAccess.open(PATH, FileAccess.WRITE)
	partial_file.store_string('{"version": 1, "character": "woman", "levels": {"01": {"stars": 2}}, "unlocked": ["01", "02"]}')
	partial_file.close()
	var partial := SaveStore.new(PATH)
	partial.load_data()
	check(not partial.levels["01"].has("best_seconds"), "Loading a partial entry preserves the absent completion time.")
	check(partial.save(), "A partial save can be written again.")
	var partial_reloaded := SaveStore.new(PATH)
	partial_reloaded.load_data()
	check(
		partial_reloaded.character == "woman" and partial_reloaded.stars("01") == 2 and partial_reloaded.is_unlocked("02"),
		"Saving and loading a partial entry preserves progress.",
	)
	check(not FileAccess.file_exists("user://test-save.corrupt.json"), "A valid partial save is not treated as corrupt.")
	check(not partial_reloaded.settings.has("control_display"), "Legacy saves retain an absent display choice.")
	for display: String in ["keyboard", "gamepad", "touch"]:
		partial_reloaded.settings["control_display"] = display
		check(partial_reloaded.save(), "Display choice writes.")
		var preference := SaveStore.new(PATH)
		preference.load_data()
		check(preference.settings.get("control_display") == display, "Display preference round trips: " + display)
		check(preference.stars("01") == 2 and preference.is_unlocked("02"), "Display choice does not reset progress.")
	if FileAccess.file_exists("user://test-save.corrupt.json"):
		DirAccess.remove_absolute("user://test-save.corrupt.json")
	var cosmetic_file := FileAccess.open(PATH, FileAccess.WRITE)
	cosmetic_file.store_string('{"version":1,"character":"woman","levels":{"01":{"stars":2,"best_seconds":42}},"unlocked":["01","02"],"settings":{"control_display":{"bad":true},"music_volume":0.4}}')
	cosmetic_file.close()
	var cosmetic := SaveStore.new(PATH)
	cosmetic.load_data()
	check(cosmetic.stars("01") == 2 and cosmetic.best_seconds("01") == 42.0 and cosmetic.is_unlocked("02"), "Invalid cosmetic preference preserves gameplay progress.")
	check(not cosmetic.settings.has("control_display") and cosmetic.get("warning_message") is String and not String(cosmetic.get("warning_message")).is_empty(), "Invalid cosmetic preference resets only itself with a warning.")
	check(not FileAccess.file_exists("user://test-save.corrupt.json"), "Invalid cosmetic preference does not quarantine valid progress.")
	partial_reloaded.record("01", 3, 40.0, 1)
	check(partial_reloaded.best_seconds("01") == 40.0, "A real completion establishes the missing best time.")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	var broken := SaveStore.new(PATH)
	broken.load_data()
	check(FileAccess.file_exists("user://test-save.corrupt.json"), "A corrupt save is renamed.")
	check(broken.is_unlocked("01") and not broken.is_unlocked("02"), "A corrupt save starts fresh.")
	for bad: String in [
		'{"version": 1, "character": "robot"}',
		'{"version": 1, "unlocked": ["01", "99"]}',
		'{"version": 1, "levels": {"01": {"stars": 7}}}',
		'{"version": 1, "levels": {"01": {"stars": 3.9}}}',
		'{"version": 1, "levels": {"01": {"stars": -0.5}}}',
		'{"version": 1, "levels": {"01": {"best_optional": 1.5}}}',
		'{"version": 1, "levels": {"01": {"best_optional": -0.5}}}',
		'{"version": 1, "settings": {"music_volume": "loud"}}',
	]:
		if FileAccess.file_exists("user://test-save.corrupt.json"):
			DirAccess.remove_absolute("user://test-save.corrupt.json")
		var bad_file := FileAccess.open(PATH, FileAccess.WRITE)
		bad_file.store_string(bad)
		bad_file.close()
		var invalid := SaveStore.new(PATH)
		invalid.load_data()
		check(
			FileAccess.file_exists("user://test-save.corrupt.json") and invalid.character == "man" and not invalid.is_unlocked("02"),
			"Invalid content resets the save: " + bad,
		)
	check(SaveStore.next_level_id("01") == "02" and SaveStore.next_level_id("05") == "", "next_level_id follows the level order.")
	clear()
	print("SAVE_STORE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
