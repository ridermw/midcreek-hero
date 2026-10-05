extends Node2D

const SIZE := Vector2(64, 16)
const ART_RECT := Rect2(-32, -32, 64, 32)

var active: bool = true
var art: RefCounted
var _time: float = 0.0
var _frame: int = -1


func advance(delta: float) -> void:
	if art != null:
		_time += delta
		var next: int = int(_time * 4.0) % art.frame_count("hazards", "cable-snag")
		if next != _frame:
			_frame = next
			queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func _draw() -> void:
	if art != null:
		var frame: int = maxi(_frame, 0)
		draw_texture_rect(art.texture("hazards", "cable-snag", frame), ART_RECT, false)
		return
	draw_rect(Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y), Color(0.95, 0.55, 0.1))
