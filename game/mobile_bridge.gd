extends Node

const MobileInput = preload("res://game/mobile_input.gd")

var enabled := false
var input := MobileInput.new()
var main: Node
var revision := 0
var _controls: Dictionary = {}
var _callback: JavaScriptObject
var _browser: JavaScriptObject
var _publish_after := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	if not OS.has_feature("web"):
		return
	_browser = JavaScriptBridge.get_interface("MidcreekTouch")
	if _browser == null:
		return
	enabled = bool(_browser.enabled)
	if enabled:
		_callback = JavaScriptBridge.create_callback(_on_browser_command)
		_browser.connectGame(_callback)


func _on_browser_command(arguments: Array) -> void:
	var data = JSON.parse_string(String(arguments[0]))
	if not data is Dictionary or not command(data):
		_browser.reportError("The touch command is no longer available.")


func invalidate() -> void:
	revision += 1
	input.clear()
	_controls.clear()
	_publish_after = 0.0
	if enabled and _browser != null:
		_browser.releaseAll()


func command(data: Dictionary) -> bool:
	if not enabled:
		return false
	match data.get("type", ""):
		"clear":
			input.clear()
			return true
		"suspend":
			input.clear()
			if main.screen_name == "level" and not get_tree().paused:
				main.toggle_pause()
			return true
		"pause":
			if main.screen_name != "level":
				return false
			main.audio.unlock()
			main.toggle_pause()
			return true
		"action":
			if main.screen_name != "level" or get_tree().paused:
				return false
			if bool(data.get("down", false)):
				main.audio.unlock()
			return input.set_action(StringName(data.get("action", "")), bool(data.get("down", false)))
		"menu":
			if data.get("revision", -1) != revision:
				return false
			var control = _controls.get(String(data.get("id", "")))
			if not is_instance_valid(control):
				return false
			if control is Button and not control.disabled:
				main.audio.unlock()
				control.pressed.emit()
				return true
			if control is HSlider and data.get("value") is float:
				var value: float = data["value"]
				if is_finite(value) and value >= control.min_value and value <= control.max_value:
					main.audio.unlock()
					control.value = value
					return true
	return false


func menu_model() -> Dictionary:
	var source: Node = main.pause_menu if get_tree().paused and main.screen_name == "level" else main.screen
	var model := {"screen": main.screen_name, "paused": get_tree().paused, "revision": revision, "controls": [], "summary": ""}
	_controls.clear()
	if main.screen_name == "level" and not get_tree().paused:
		return model
	var labels: Array[String] = []
	var last_label := ""
	for node: Node in source.find_children("*", "", true, false):
		if node is Label and not node.text.is_empty():
			labels.append(node.text)
			last_label = node.text
		elif node is Button:
			var id := str(node.get_instance_id())
			_controls[id] = node
			model["controls"].append({"id": id, "kind": "button", "text": node.text, "disabled": node.disabled})
		elif node is HSlider:
			var id := str(node.get_instance_id())
			_controls[id] = node
			model["controls"].append({"id": id, "kind": "slider", "text": last_label, "value": node.value, "min": node.min_value, "max": node.max_value, "step": node.step})
	if main.screen_name == "results":
		labels.append("%d stars" % main.screen.stars)
	if main.screen_name == "level_select":
		for id: String in main.level_ids():
			labels.append("Work order %s: %d stars" % [id, main.save.stars(id)])
	model["summary"] = "\n".join(labels)
	return model


func _physics_process(_delta: float) -> void:
	input.advance()


func _process(delta: float) -> void:
	if not enabled or _browser == null:
		return
	_publish_after -= delta
	if _publish_after > 0.0:
		return
	_publish_after = 0.1
	var model := menu_model()
	if main.screen_name == "level" and is_instance_valid(main.screen.hud):
		var hud = main.screen.hud
		model["prompt"] = touch_prompt(hud.prompt_label.text)
		model["status"] = "%s | Health %d/5" % [hud.timer_label.text, main.screen.health.segments]
		model["tasks"] = "\n".join(hud.task_lines())
		model["carry"] = hud.carry_label.text
	_browser.render(JSON.stringify(model))


static func touch_prompt(text: String) -> String:
	var replacements := {
		"Run: A / D or arrows. Pad: left stick": "Run with Left and Right.",
		"Space. Pad: A": "Jump",
		"hold E. Pad: hold X": "hold Repair",
		"E / X": "Repair", "Q / Y": "Diagnose", "Space / A": "Jump",
		"E or X": "Repair", "Q or Y": "Diagnose",
		"Hold E": "Hold Repair", "hold E": "hold Repair",
		"Press Q": "Press Diagnose", "press E": "press Repair",
		"C or Shift": "Slide", "with C": "with Slide", "W or Up": "Up",
	}
	for original: String in replacements:
		text = text.replace(original, replacements[original])
	return text
