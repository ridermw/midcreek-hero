extends Node2D

const RANGE_X := 32.0

var task_id: String = ""
var order: int = 1
var on: bool = false
var art: RefCounted


func in_range(feet: Vector2) -> bool:
	return absf(feet.x - position.x) <= RANGE_X and absf(feet.y - position.y) <= 16.0


func set_on(value: bool) -> void:
	if on != value:
		on = value
		queue_redraw()


func capture_state() -> Dictionary:
	return {"on": on}


func restore_state(saved: Dictionary) -> void:
	set_on(bool(saved["on"]))


func _draw() -> void:
	var name := "switch-on" if on else "switch-off"
	if art != null and art.has("tiles", name):
		draw_texture(art.texture("tiles", name), Vector2(-16, -48))
	else:
		draw_rect(Rect2(-16, -48, 32, 48), Color(0.3, 0.6, 0.3) if on else Color(0.5, 0.2, 0.2))
	draw_rect(Rect2(-9, -70, 18, 18), Color(0.04, 0.07, 0.1, 0.85))
	draw_string(ThemeDB.fallback_font, Vector2(-5, -55), str(order), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.95, 0.3) if on else Color.WHITE)
