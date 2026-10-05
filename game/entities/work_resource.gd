extends Node2D

const WorkOrder = preload("res://game/tasks/work_order.gd")

var order: WorkOrder
var index := 0
var art: RefCounted


func in_range(feet: Vector2) -> bool:
	return absf(feet.x - position.x) <= 28.0 and absf(feet.y - position.y) <= 16.0


func is_refill() -> bool:
	return order.definition["type"] == "extinguish_fire" and order.unit.equipped and not order.done


func available() -> bool:
	return is_refill() or order.inventory.available(order.resource_id(index))


func capture_state() -> Dictionary:
	return {}


func restore_state(_state: Dictionary) -> void:
	queue_redraw()


func _draw() -> void:
	if not available():
		return
	var kind: String = order.definition["resources"][index]["kind"]
	if art != null:
		var texture: Texture2D = art.texture("props" if kind in ["psu", "dimm"] else "work", kind)
		draw_texture(texture, -Vector2(texture.get_width() / 2.0, texture.get_height()))
	else:
		draw_rect(Rect2(-10, -24, 20, 24), Color(0.2, 0.8, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(-24, -106 if kind == "chassis" else -58), "%s %s" % [order.definition["id"], "refill" if is_refill() else kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
