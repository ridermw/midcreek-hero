extends Node2D

var open: bool = false
var art: RefCounted


func set_open(value: bool) -> void:
	if open != value:
		open = value
		queue_redraw()


func in_range(feet: Vector2) -> bool:
	return absf(feet.x - position.x) <= 16.0 and absf(feet.y - position.y) <= 16.0


func _draw() -> void:
	if art != null:
		draw_texture(art.texture("tiles", "exit-open" if open else "exit-closed"), Vector2(-32, -96))
		return
	draw_rect(Rect2(-24, -96, 48, 96), Color(0.2, 0.62, 0.35) if open else Color(0.45, 0.12, 0.12))
