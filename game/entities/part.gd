extends Node2D

const LABELS := {"psu": "PSU", "dimm": "DIMM"}

var task_id: String = ""
var kind: String = "psu"
var taken: bool = false
var art: RefCounted


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-10, -24), Vector2(20, 24))


func take() -> void:
	taken = true
	hide()


func capture_state() -> Dictionary:
	return {"taken": taken}


func restore_state(state: Dictionary) -> void:
	taken = bool(state["taken"])
	visible = not taken


func _draw() -> void:
	if art != null and art.has("props", kind):
		draw_texture(art.texture("props", kind), Vector2(-8, -20))
		return
	draw_rect(Rect2(-8, -20, 16, 16), Color(0.5, 0.55, 0.6) if kind == "psu" else Color(0.2, 0.6, 0.3))
