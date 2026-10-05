extends Node2D

const WorkOrder = preload("res://game/tasks/work_order.gd")

var order: WorkOrder
var sites: Array[Vector2] = []
var effects: Array[Node2D] = []
var art: RefCounted


func site_in_range(feet: Vector2) -> int:
	var nearest := -1
	var distance := INF
	for i: int in range(sites.size()):
		var dx := absf(feet.x - sites[i].x)
		if dx <= 32.0 and absf(feet.y - sites[i].y) <= 16.0 and dx < distance:
			nearest = i
			distance = dx
	return nearest


func capture_state() -> Dictionary:
	return order.capture_state()


func restore_state(state: Dictionary) -> void:
	order.restore_state(state)
	queue_redraw()


func apply_effects() -> void:
	for hazard: Node2D in effects:
		if order.definition["type"] == "extinguish_fire":
			hazard.intensity = order.unit.intensity
		if hazard.has_method("set_enabled"):
			hazard.set_enabled(not order.done)
		else:
			hazard.active = not order.done
			hazard.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var kind: String = order.definition["type"]
	var color := Color(0.3, 0.9, 0.5) if order.done else Color(1.0, 0.75, 0.2)
	if kind == "run_cable":
		for i: int in range(1, mini(order.unit.next_point, sites.size())):
			draw_line(sites[i - 1] + Vector2(0, -40), sites[i] + Vector2(0, -40), Color(0.15, 0.75, 0.95), 3.0)
	for i: int in range(sites.size()):
		var group := "tiles"
		var asset := "switch-on" if order.done else "switch-off"
		if kind == "assemble_rack":
			group = "tiles" if order.done else "work"
			asset = "rack-ok" if order.done else "chassis"
		elif kind in ["restore_cooling", "contain_leak"]:
			group = "work"
			asset = "valve"
		elif kind == "extinguish_fire":
			group = "work"
			asset = "extinguisher"
		var height := 48.0
		if art != null:
			var texture: Texture2D = art.texture(group, asset)
			height = texture.get_height()
			draw_texture(texture, sites[i] - Vector2(texture.get_width() / 2.0, height))
		else:
			draw_rect(Rect2(sites[i] - Vector2(12, height), Vector2(24, height)), color)
		draw_circle(sites[i] + Vector2(10, -height + 8), 3.0, color)
		var label := "%s %d" % [order.definition["id"], i + 1]
		draw_string(ThemeDB.fallback_font, sites[i] + Vector2(-24, -height - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		if kind == "assemble_rack" and not order.done and art != null:
			for component: String in ["psu", "dimm"]:
				if component in order.unit.installed:
					draw_texture(art.texture("props", component), sites[i] + Vector2(-8, -70 if component == "psu" else -45))
