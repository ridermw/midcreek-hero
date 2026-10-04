extends Node2D

var taken: bool = false
var art: RefCounted
var _time: float = 0.0


func _process(delta: float) -> void:
	if art != null and not taken:
		_time += delta
		queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-8, -16), Vector2(16, 16))


func take() -> void:
	taken = true
	hide()


func _draw() -> void:
	if art != null:
		var frame: int = int(_time * 8.0) % art.frame_count("props", "coolant")
		draw_texture(art.texture("props", "coolant", frame), Vector2(-8, -16))
		return
	draw_rect(Rect2(-8, -16, 16, 16), Color(0.3, 0.75, 0.95))
