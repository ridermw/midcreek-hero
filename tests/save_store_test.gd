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
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	var broken := SaveStore.new(PATH)
	broken.load_data()
	check(FileAccess.file_exists("user://test-save.corrupt.json"), "A corrupt save is renamed.")
	check(broken.is_unlocked("01") and not broken.is_unlocked("02"), "A corrupt save starts fresh.")
	check(SaveStore.next_level_id("01") == "02" and SaveStore.next_level_id("05") == "", "next_level_id follows the level order.")
	clear()
	print("SAVE_STORE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
