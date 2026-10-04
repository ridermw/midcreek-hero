extends Node2D

var taken: bool = false


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-8, -16), Vector2(16, 16))


func take() -> void:
	taken = true
	hide()


func _draw() -> void:
	draw_rect(Rect2(-8, -16, 16, 16), Color(0.3, 0.75, 0.95))
