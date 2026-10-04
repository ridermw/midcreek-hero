extends Node2D

var reached: bool = false
var art: RefCounted
var _time: float = 0.0


func _process(delta: float) -> void:
	if reached and art != null:
		_time += delta
		queue_redraw()


func in_range(feet: Vector2) -> bool:
	return absf(feet.x - position.x) <= 16.0 and absf(feet.y - position.y) <= 16.0


func set_reached() -> void:
	reached = true
	queue_redraw()


func _draw() -> void:
	if art != null:
		var frame: int = int(_time * 8.0) % art.frame_count("tiles", "checkpoint-on") if reached else 0
		draw_texture(art.texture("tiles", "checkpoint-on" if reached else "checkpoint-off", frame), Vector2(-16, -64))
		return
	draw_rect(Rect2(-2, -64, 4, 64), Color(0.45, 0.5, 0.55))
	draw_circle(Vector2(0, -66), 5.0, Color(0.16, 0.68, 0.39) if reached else Color(0.3, 0.33, 0.36))
