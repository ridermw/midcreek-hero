extends Node2D

var active := true
var intensity := 3.0
var art: RefCounted
var _time := 0.0


func advance(delta: float) -> void:
	if active:
		_time += delta
		queue_redraw()


func hit_rect() -> Rect2:
	var height := _flame_height() - 8
	return Rect2(position + Vector2(-14, -height), Vector2(28, height))


func _flame_height() -> int:
	return maxi(16, roundi(64.0 * clampf(intensity / 3.0, 0.0, 1.0)))


func reset_motion() -> void:
	_time = 0.0
	queue_redraw()


func _draw() -> void:
	if not active:
		draw_rect(Rect2(-14, -3, 28, 3), Color(0.2, 0.22, 0.24))
	elif art != null:
		var height := _flame_height()
		draw_texture_rect(art.texture("work", "fire", int(_time * 8) % 4), Rect2(-16, -height, 32, height), false)
	else:
		var height := _flame_height() - 8
		draw_rect(Rect2(-14, -height, 28, height), Color(1.0, 0.4, 0.1))
