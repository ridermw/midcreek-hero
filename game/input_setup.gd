extends RefCounted

const KEYS := {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"jump": [KEY_SPACE, KEY_W, KEY_UP],
	&"repair": [KEY_E],
	&"diagnose": [KEY_Q],
	&"slide": [KEY_S, KEY_DOWN],
	&"pause": [KEY_ESCAPE, KEY_P],
}
const BUTTONS := {
	&"move_left": [JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"jump": [JOY_BUTTON_A],
	&"repair": [JOY_BUTTON_X],
	&"diagnose": [JOY_BUTTON_Y],
	&"slide": [JOY_BUTTON_B],
	&"pause": [JOY_BUTTON_START],
}
const AXES := {&"move_left": -1.0, &"move_right": 1.0}


static func install() -> void:
	for action: StringName in KEYS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.25)
		for key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
		for button in BUTTONS[action]:
			var pad := InputEventJoypadButton.new()
			pad.button_index = button
			InputMap.action_add_event(action, pad)
		if AXES.has(action):
			var axis := InputEventJoypadMotion.new()
			axis.axis = JOY_AXIS_LEFT_X
			axis.axis_value = AXES[action]
			InputMap.action_add_event(action, axis)
