extends Node2D

var active := true
var art: RefCounted
var _time := 0.0


func advance(delta: float) -> void:
	if active:
		_time += delta
		queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-14, -56), Vector2(28, 56))


func reset_motion() -> void:
	_time = 0.0
	queue_redraw()


func _draw() -> void:
	if not active:
		draw_rect(Rect2(-14, -3, 28, 3), Color(0.2, 0.22, 0.24))
	elif art != null:
		draw_texture(art.texture("work", "fire", int(_time * 8) % 4), Vector2(-16, -64))
	else:
		draw_rect(Rect2(-14, -56, 28, 56), Color(1.0, 0.4, 0.1))
