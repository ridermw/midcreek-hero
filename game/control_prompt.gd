extends RefCounted

const InputSetup = preload("res://game/input_setup.gd")
const PAD_LABELS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_DPAD_LEFT: "←", JOY_BUTTON_DPAD_RIGHT: "→",
	JOY_BUTTON_DPAD_UP: "↑", JOY_BUTTON_DPAD_DOWN: "↓", JOY_BUTTON_START: "Menu",
}
const TOUCH_LABELS := {
	"move_left": "Left", "move_right": "Right", "move_up": "Up", "move_down": "Down",
	"jump": "Jump", "slide": "Slide", "repair": "Repair", "diagnose": "Diagnose", "pause": "Pause",
}


static func make(action := "", intent := "", text := "", status := "", held := false) -> Dictionary:
	return {"action": action, "intent": intent, "text": text, "status": status, "held": held, "pulse": not action.is_empty()}


static func valid(prompt: Dictionary) -> bool:
	for key: String in ["action", "intent", "text", "status"]:
		if not prompt.get(key) is String:
			return false
	if prompt["action"].is_empty():
		return prompt["intent"].is_empty()
	return InputSetup.KEYS.has(StringName(prompt["action"])) and prompt["intent"] in ["press", "hold"] and not prompt["text"].is_empty()


static func graphic(action: String, display: String) -> Dictionary:
	if action.is_empty():
		return {}
	if display == "gamepad":
		return {"shape": "button", "label": PAD_LABELS[InputSetup.BUTTONS[StringName(action)][0]]}
	if display == "touch":
		return {"shape": "touch", "label": TOUCH_LABELS[action]}
	return {"shape": "keycap", "label": OS.get_keycode_string(InputSetup.KEYS[StringName(action)][0])}


static func render(prompt: Dictionary, display: String) -> Dictionary:
	var result := make()
	result.merge(prompt, true)
	result["display"] = display
	result["graphic"] = graphic(result["action"], display)
	var description: String = result["status"]
	if not result["action"].is_empty():
		description = "%s %s to %s" % [String(result["intent"]).capitalize(), result["graphic"]["label"], result["text"]]
		if not result["status"].is_empty():
			description += ". " + result["status"]
	elif not result["text"].is_empty():
		description = result["text"] + (". " + description if not description.is_empty() else "")
	result["description"] = description
	return result
