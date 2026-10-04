extends RefCounted

const ACTIONS := [&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"slide", &"repair", &"diagnose"]

var _held: Dictionary = {}
var _pending: Dictionary = {}
var _pressed: Dictionary = {}


func set_action(action: StringName, down: bool) -> bool:
	if action not in ACTIONS:
		return false
	if down and not held(action):
		_pending[action] = true
	_held[action] = down
	return true


func advance() -> void:
	_pressed = _pending
	_pending = {}


func held(action: StringName) -> bool:
	return _held.get(action, false)


func pressed(action: StringName) -> bool:
	return _pressed.get(action, false)


func clear() -> void:
	_held.clear()
	_pending.clear()
	_pressed.clear()
