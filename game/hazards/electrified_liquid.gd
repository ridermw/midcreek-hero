extends Node2D

const SIZE := Vector2(32, 8)
const FRAME_COUNT := 4
const FPS := 8.0
var active := true
var fatal := true
var art: RefCounted
var _time := 0.0
var _frame := 0


func advance(delta: float) -> void:
	if not active:
		return
	_time += delta
	var next := int(_time * FPS) % FRAME_COUNT
	if next != _frame:
		_frame = next
		queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-16, -8), SIZE)


func capture_state() -> Dictionary:
	return {"active": active}


func restore_state(state: Dictionary) -> void:
	active = bool(state["active"])
	queue_redraw()


func reset_motion() -> void:
	_time = 0.0
	_frame = 0
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	if art != null:
		draw_texture(art.texture("hazards", "electrified-liquid", _frame), Vector2(-16, -16))
		return
	draw_rect(Rect2(-16, -8, 32, 8), Color(0.1, 0.6, 0.8))
	draw_line(Vector2(-12, -5), Vector2(12, -3), Color.WHITE, 2)
