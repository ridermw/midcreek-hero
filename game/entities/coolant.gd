extends Node2D

var taken: bool = false
var art: RefCounted
var _time: float = 0.0
var _frame: int = -1


func _process(delta: float) -> void:
	if art != null and not taken:
		_time += delta
		var next: int = int(_time * 8.0) % art.frame_count("props", "coolant")
		if next != _frame:
			_frame = next
			queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-8, -16), Vector2(16, 16))


func capture_state() -> Dictionary:
	return {"taken": taken}


func restore_state(state: Dictionary) -> void:
	taken = bool(state["taken"])
	visible = not taken


func take() -> void:
	taken = true
	hide()


func _draw() -> void:
	if art != null:
		var frame: int = maxi(_frame, 0)
		draw_texture(art.texture("props", "coolant", frame), Vector2(-8, -16))
		return
	draw_rect(Rect2(-8, -16, 16, 16), Color(0.3, 0.75, 0.95))
