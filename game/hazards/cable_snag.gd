extends Node2D

const SIZE := Vector2(28, 10)

var active: bool = true


func advance(_delta: float) -> void:
	pass


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func _draw() -> void:
	draw_rect(Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y), Color(0.95, 0.55, 0.1))
