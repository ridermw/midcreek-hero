extends Node

const InputSetup = preload("res://game/input_setup.gd")
const SaveStore = preload("res://game/save_store.gd")
const SpriteLibrary = preload("res://game/sprite_library.gd")
const HeroAnimations = preload("res://game/animation_library.gd")
const UiKit = preload("res://game/menus/ui_kit.gd")
const AudioDirector = preload("res://game/audio_director.gd")
const LEVEL_SCENE := preload("res://game/level.tscn")
const LEVEL_DIR := "res://levels/"
const SCREENS := {
	"title": preload("res://game/menus/title.gd"),
	"character_select": preload("res://game/menus/character_select.gd"),
	"level_select": preload("res://game/menus/level_select.gd"),
	"results": preload("res://game/menus/results.gd"),
}

@export var save_path: String = "user://save.json"

var save: SaveStore
var art := SpriteLibrary.new()
var animations := HeroAnimations.new()
var screen: Node
var screen_name: String = ""
var current_level_id: String = ""
var pause_menu: CanvasLayer
var _pause_first: Button
var error_message: String = ""
var audio: AudioDirector
var last_sfx: String = ""
var _level_files: Dictionary = {}
var _level_names: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.install()
	save = SaveStore.new(save_path)
	save.load_data()
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	audio.set_bus_volume("Music", float(save.settings["music_volume"]))
	audio.set_bus_volume("SFX", float(save.settings["sfx_volume"]))
	get_viewport().gui_focus_changed.connect(func(_control: Control) -> void: play_sfx("menu_move"))
	if not art.load_all() or not animations.load_manifest():
		error_message = art.error_message if not art.error_message.is_empty() else animations.error_message
		add_child(UiKit.label(error_message, 20))
		return
	_scan_levels()
	_build_pause_menu()
	go_to("title")


func music_name() -> String:
	return audio.current_music if audio.unlocked else audio.pending_music


func play_sfx(sound_name: String) -> void:
	last_sfx = sound_name
	audio.play_sfx(sound_name)


func level_ids() -> Array[String]:
	var ids: Array[String] = []
	for level_id: String in _level_files:
		ids.append(level_id)
	ids.sort()
	return ids


func level_name(level_id: String) -> String:
	return _level_names.get(level_id, level_id)


func level_button(level_id: String) -> Button:
	if screen_name != "level_select":
		return null
	return screen.buttons.get(level_id)


func next_playable(level_id: String) -> String:
	var next := SaveStore.next_level_id(level_id)
	if next.is_empty() or not _level_files.has(next) or not save.is_unlocked(next):
		return ""
	return next


func go_to(target: String, data: Dictionary = {}) -> void:
	get_tree().paused = false
	if pause_menu != null:
		pause_menu.hide()
	if screen != null:
		remove_child(screen)
		screen.queue_free()
	screen_name = target
	if target == "level":
		var level := LEVEL_SCENE.instantiate()
		level.level_path = _level_files[current_level_id]
		level.character = save.character
		level.process_mode = Node.PROCESS_MODE_PAUSABLE
		level.finished.connect(_on_level_finished)
		level.sound.connect(play_sfx)
		screen = level
	else:
		var control := Control.new()
		control.set_script(SCREENS[target])
		screen = control
	add_child(screen)
	move_child(screen, 0)
	if target == "results":
		screen.build(self, data)
		audio.play_music("results")
	elif target == "level":
		if screen.error_message.is_empty():
			audio.play_music(String(screen.level["header"]["music"]))
	else:
		screen.build(self)
		audio.play_music("title")
	for button: Node in screen.find_children("*", "Button", true, false):
		(button as Button).pressed.connect(play_sfx.bind("menu_select"))


func choose_character(character: String) -> void:
	save.character = character
	save.save()
	go_to("level_select")


func start_level(level_id: String) -> void:
	current_level_id = level_id
	go_to("level")


func toggle_pause() -> void:
	if screen_name != "level":
		return
	var pausing := not get_tree().paused
	get_tree().paused = pausing
	pause_menu.visible = pausing
	if pausing:
		_pause_first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and screen_name == "level":
		toggle_pause()
		get_viewport().set_input_as_handled()


func _on_level_finished(result: Dictionary) -> void:
	save.record(current_level_id, int(result["stars"]), float(result["elapsed"]), int(result["optional_done"]))
	save.save()
	_show_results.call_deferred(result)


func _show_results(result: Dictionary) -> void:
	go_to("results", {"level_id": current_level_id, "result": result})


func _scan_levels() -> void:
	var parser := preload("res://game/level_parser.gd").new()
	for file_name: String in DirAccess.get_files_at(LEVEL_DIR):
		if not file_name.ends_with(".level") or file_name.begins_with("00-"):
			continue
		var level_id := file_name.substr(0, 2)
		var path := LEVEL_DIR + file_name
		var level := parser.parse(FileAccess.get_file_as_string(path), path)
		if level.is_empty():
			continue
		_level_files[level_id] = path
		_level_names[level_id] = String(level["header"]["name"])


func _build_pause_menu() -> void:
	pause_menu = CanvasLayer.new()
	pause_menu.layer = 10
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.hide()
	add_child(pause_menu)
	var menu := Control.new()
	menu.name = "Menu"
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(menu)
	var box := UiKit.column(menu)
	(menu.get_child(0) as ColorRect).color = Color(0.03, 0.05, 0.08, 0.82)
	box.add_child(UiKit.label("Paused", 32))
	var buttons: Array = []
	for entry: Array in [
		["Resume", toggle_pause],
		["Restart work order", func() -> void: start_level(current_level_id)],
		["Quit to level select", func() -> void: go_to("level_select")],
	]:
		var item := UiKit.button(entry[0], art)
		item.pressed.connect(entry[1])
		box.add_child(item)
		buttons.append(item)
	_pause_first = buttons[0]
	for i: int in range(buttons.size()):
		var current: Button = buttons[i]
		current.focus_neighbor_top = current.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		current.focus_neighbor_bottom = current.get_path_to(buttons[(i + 1) % buttons.size()])
