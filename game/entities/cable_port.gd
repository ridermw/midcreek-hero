extends Node2D

const BUTTONS: Array[StringName] = [&"repair", &"diagnose", &"jump"]
const WINDOW_SECONDS := 1.0
const RANGE_X := 40.0

var task_id: String = ""
var done: bool = false
var state: String = "idle"
var step: int = 0
var window_remaining: float = 0.0
var art: RefCounted


static func sequence_for(id: String) -> Array[StringName]:
	var n := absi(hash(id)) % 27
	return [BUTTONS[n / 9], BUTTONS[(n / 3) % 3], BUTTONS[n % 3]]


func in_range(feet: Vector2) -> bool:
	return absf(feet.x - position.x) <= RANGE_X and absf(feet.y - position.y) <= 16.0


func begin() -> void:
	state = "active"
	step = 0
	window_remaining = WINDOW_SECONDS
	queue_redraw()


func current_button() -> StringName:
	return sequence_for(task_id)[step]


func press(button: StringName) -> String:
	if state != "active":
		return "ignored"
	if button != current_button():
		_reset()
		return "wrong"
	step += 1
	if step >= 3:
		done = true
		_reset()
		return "done"
	window_remaining = WINDOW_SECONDS
	queue_redraw()
	return "ok"


func advance(delta: float) -> bool:
	if state != "active":
		return false
	window_remaining -= delta
	if window_remaining <= 0.0:
		_reset()
		return true
	return false


func capture_state() -> Dictionary:
	return {"done": done}


func restore_state(saved: Dictionary) -> void:
	done = bool(saved["done"])
	_reset()


func _reset() -> void:
	state = "idle"
	step = 0
	window_remaining = 0.0
	queue_redraw()


func _draw() -> void:
	if art != null and art.has("tiles", "cable-port"):
		draw_texture(art.texture("tiles", "cable-port"), Vector2(-16, -72))
	else:
		draw_rect(Rect2(-16, -72, 32, 32), Color(0.3, 0.35, 0.4))
	var light := Color(0.16, 0.68, 0.39) if done else Color(0.98, 0.7, 0.15)
	draw_rect(Rect2(-3, -80, 6, 6), light)
	if state == "active":
		for i: int in range(3):
			var lit := Color(0.6, 0.95, 0.3) if i < step else Color(0.25, 0.28, 0.3)
			draw_rect(Rect2(-13 + i * 10, -38, 6, 4), lit)
