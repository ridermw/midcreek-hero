extends Node2D

const SIZE := Vector2(28, 10)

var active: bool = true
var art: RefCounted
var _time: float = 0.0


func advance(delta: float) -> void:
	if art != null:
		_time += delta
		queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func _draw() -> void:
	if art != null:
		var frame: int = int(_time * 4.0) % art.frame_count("hazards", "cable-snag")
		draw_texture(art.texture("hazards", "cable-snag", frame), Vector2(-16, -16))
		return
	draw_rect(Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y), Color(0.95, 0.55, 0.1))
