extends Node

const InputSetup = preload("res://game/input_setup.gd")
const SaveStore = preload("res://game/save_store.gd")
const SpriteLibrary = preload("res://game/sprite_library.gd")
const HeroAnimations = preload("res://game/animation_library.gd")
const UiKit = preload("res://game/menus/ui_kit.gd")
const AudioDirector = preload("res://game/audio_director.gd")
const RouteRunner = preload("res://game/route_runner.gd")
const MobileBridge = preload("res://game/mobile_bridge.gd")
const LEVEL_SCENE := preload("res://game/level.tscn")
const LEVEL_DIR := "res://levels/"
const SCREENS := {
	"title": preload("res://game/menus/title.gd"),
	"character_select": preload("res://game/menus/character_select.gd"),
	"level_select": preload("res://game/menus/level_select.gd"),
	"results": preload("res://game/menus/results.gd"),
	"settings": preload("res://game/menus/settings.gd"),
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
var route_runner: RouteRunner
var smoke: bool = false
var quit_after_smoke: bool = true
var _smoke_report: float = 0.0
var _master_was_muted: bool = false
var _level_files: Dictionary = {}
var _level_names: Dictionary = {}
var mobile: Node
var help_menu: CanvasLayer
var help_view: Control
var notice_message := ""
var notice_label: Label
var animation_probe_enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.install()
	var query := String(JavaScriptBridge.eval("location.search")) if OS.has_feature("web") else ""
	animation_probe_enabled = wants_animation_probe(query, OS.has_feature("debug"))
	save = SaveStore.new(save_path)
	save.load_data()
	var notices := CanvasLayer.new()
	notices.layer = 30
	add_child(notices)
	notice_label = Label.new()
	notice_label.position = Vector2(12, 8)
	notice_label.size = Vector2(936, 60)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
	notices.add_child(notice_label)
	show_notice(save.warning_message)
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	audio.set_bus_volume("Music", float(save.settings["music_volume"]))
	audio.set_bus_volume("SFX", float(save.settings["sfx_volume"]))
	mobile = MobileBridge.new()
	mobile.main = self
	add_child(mobile)
	get_viewport().gui_focus_changed.connect(func(_control: Control) -> void: play_sfx("menu_move"))
	if not art.load_all() or not animations.load_manifest():
		error_message = art.error_message if not art.error_message.is_empty() else animations.error_message
		add_child(UiKit.label(error_message, 20))
		return
	_scan_levels()
	_build_pause_menu()
	var smoke_id := route_from_args(OS.get_cmdline_user_args())
	if OS.has_feature("web"):
		smoke_id = route_from_query(query)
	if not smoke_id.is_empty() and _level_files.has(smoke_id):
		start_smoke(smoke_id)
	else:
		go_to("title")


static func route_from_query(query: String) -> String:
	for part: String in query.trim_prefix("?").split("&"):
		if part.begins_with("route="):
			var id := part.trim_prefix("route=")
			if id.length() == 2 and id.is_valid_int():
				return id
	return ""


static func route_from_args(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.begins_with("--route="):
			return route_from_query("route=" + arg.trim_prefix("--route="))
	return ""


static func wants_animation_probe(query: String, debug_build: bool) -> bool:
	return debug_build and "animation_probe=1" in query.trim_prefix("?").split("&")


func animation_probe_state() -> Dictionary:
	var state := {"screen": screen_name, "character": save.character, "paused": get_tree().paused, "error": error_message}
	if screen_name != "level" or not is_instance_valid(screen):
		return state
	var player = screen.player
	var sprite: AnimatedSprite2D = player.sprite
	state.merge({
		"level_id": current_level_id, "character": screen.character, "error": screen.error_message,
		"position": [player.position.x, player.position.y],
		"velocity": [player.velocity.x, player.velocity.y],
		"clip": String(sprite.animation), "frame": sprite.frame, "progress": sprite.frame_progress,
		"playing": sprite.is_playing(), "playback_speed": sprite.get_playing_speed(),
		"physics_frame": Engine.get_physics_frames(), "elapsed": screen.timer.elapsed,
		"facing_left": sprite.flip_h,
		"climbing": player.motor.climbing, "locked": player.locked,
		"hits": screen.health.hits_taken, "respawns": screen.respawns,
	}, true)
	return state


func _publish_animation_probe() -> void:
	if animation_probe_enabled and OS.has_feature("web"):
		JavaScriptBridge.eval("window.midcreekAnimationProbe = %s; undefined" % JSON.stringify(animation_probe_state()))


func _end_smoke() -> void:
	route_runner = null
	if smoke:
		smoke = false
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _master_was_muted)


func start_smoke(level_id: String) -> void:
	if not smoke:
		_master_was_muted = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
	smoke = true
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	start_level(level_id)
	var path: String = "res://levels/routes/" + _level_files[level_id].get_file().get_basename() + ".route.json"
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) == OK:
		route_runner = RouteRunner.new(json.data)


func _quit_smoke() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	audio.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# The audio thread releases stopped playbacks in wall time, which --fixed-fps does not advance.
	OS.delay_msec(400)
	get_tree().quit()


func set_volume(key: String, value: float) -> void:
	save.settings[key] = clampf(value, 0.0, 1.0)
	audio.set_bus_volume("Music" if key == "music_volume" else "SFX", save.settings[key])
	_persist()


func control_display() -> String:
	return String(save.settings.get("control_display", "touch" if mobile != null and mobile.enabled else "keyboard"))


func set_control_display(value: String) -> void:
	if value not in SaveStore.CONTROL_DISPLAYS:
		return
	save.settings["control_display"] = value
	_persist()
	if screen_name == "level":
		screen.hud.control_display = control_display()
	if screen_name == "settings":
		screen.refresh_choices()
		mobile.revision += 1


func _persist() -> void:
	if not save.save():
		show_notice("Could not save changes. They apply for this session only; check available storage.")
	elif not notice_message.is_empty():
		show_notice("")


func show_notice(message: String) -> void:
	notice_message = message
	notice_label.text = message
	notice_label.visible = not message.is_empty()
	if mobile != null:
		mobile.revision += 1


func smoke_status() -> String:
	if route_runner == null or screen_name != "level" or not is_instance_valid(screen):
		return "MIDCREEK SMOKE %s idle" % current_level_id
	return "MIDCREEK SMOKE %s step=%d/%d x=%d respawns=%d t=%.0f" % [
		current_level_id, route_runner.index + 1, route_runner.steps.size(),
		int(screen.player.position.x), int(screen.respawns), screen.timer.elapsed,
	]


func _physics_process(delta: float) -> void:
	if animation_probe_enabled:
		_publish_animation_probe.call_deferred()
	if route_runner != null and screen_name == "level" and is_instance_valid(screen) and not get_tree().paused:
		route_runner.apply(screen, delta)
		_smoke_report += delta
		if OS.has_feature("web") and _smoke_report >= 1.0:
			_smoke_report = 0.0
			JavaScriptBridge.eval("document.title = %s" % JSON.stringify(smoke_status()))


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
	_discard_help()
	mobile.invalidate()
	if target != "level":
		_end_smoke()
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
		level.mobile_input = mobile.input
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
			screen.hud.control_display = control_display()
			screen.hud.prompt_row.visible = not mobile.enabled
			screen.hud.prompt_label.visible = not mobile.enabled
			audio.play_music(String(screen.level["header"]["music"]))
	else:
		screen.build(self)
		audio.play_music("title")
	for button: Node in screen.find_children("*", "Button", true, false):
		(button as Button).pressed.connect(play_sfx.bind("menu_select"))


func choose_character(character: String) -> void:
	save.character = character
	_persist()
	go_to("level_select")


func start_level(level_id: String) -> void:
	current_level_id = level_id
	go_to("level")


func toggle_pause() -> void:
	if screen_name != "level":
		return
	if help_view != null:
		close_help()
		return
	mobile.invalidate()
	var pausing := not get_tree().paused
	get_tree().paused = pausing
	pause_menu.visible = pausing
	if pausing:
		screen.hud.set_prompt({})
		_pause_first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and (screen_name == "level" or help_view != null):
		if help_view != null:
			close_help()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()


func open_help() -> void:
	if help_view != null:
		return
	if screen_name == "level":
		if not get_tree().paused:
			toggle_pause()
		pause_menu.hide()
	mobile.invalidate()
	help_menu = CanvasLayer.new()
	help_menu.layer = 20
	help_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(help_menu)
	help_view = preload("res://game/menus/help.gd").new()
	help_menu.add_child(help_view)
	help_view.build(self)


func close_help() -> void:
	_discard_help()
	mobile.invalidate()
	if screen_name == "level":
		get_tree().paused = true
		pause_menu.show()
		_pause_first.grab_focus()
	elif is_instance_valid(screen):
		for button: Button in screen.find_children("*", "Button", true, false):
			if button.text == "How to Play":
				button.grab_focus()
				break


func _discard_help() -> void:
	if is_instance_valid(help_menu):
		remove_child(help_menu)
		help_menu.queue_free()
	help_view = null
	help_menu = null


func _on_level_finished(result: Dictionary) -> void:
	if not smoke:
		save.record(current_level_id, int(result["stars"]), float(result["elapsed"]), int(result["optional_done"]))
		_persist()
	_show_results.call_deferred(result)


func _show_results(result: Dictionary) -> void:
	if smoke:
		print("SMOKE_RESULT %s stars=%d respawns=%d elapsed=%.2f hits=%d sla=%.2f" % [
			current_level_id, int(result["stars"]), int(result["respawns"]),
			float(result["elapsed"]), int(result["hits"]),
			float(result["sla_seconds"]),
		])
		if quit_after_smoke and not OS.has_feature("web"):
			_quit_smoke.call_deferred()
	if smoke and OS.has_feature("web"):
		JavaScriptBridge.eval(
			"document.title = 'MIDCREEK RESULT %s stars=%d respawns=%d'" % [current_level_id, int(result["stars"]), int(result["respawns"])]
		)
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
		["How to Play", open_help],
		["Restart work order", func() -> void: start_level(current_level_id)],
		["Quit to level select", func() -> void: go_to("level_select")],
	]:
		var item := UiKit.button(entry[0], art)
		item.pressed.connect(entry[1])
		item.pressed.connect(play_sfx.bind("menu_select"))
		box.add_child(item)
		buttons.append(item)
	_pause_first = buttons[0]
	for i: int in range(buttons.size()):
		var current: Button = buttons[i]
		current.focus_neighbor_top = current.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		current.focus_neighbor_bottom = current.get_path_to(buttons[(i + 1) % buttons.size()])
