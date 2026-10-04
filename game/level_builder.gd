extends RefCounted

const Rack = preload("res://game/entities/rack.gd")
const Checkpoint = preload("res://game/entities/checkpoint.gd")
const Coolant = preload("res://game/entities/coolant.gd")
const ExitDoor = preload("res://game/entities/exit_door.gd")
const CableSnag = preload("res://game/hazards/cable_snag.gd")

const TILE := 32
const SOLID_COLORS := {
	"floor": Color(0.25, 0.29, 0.33),
	"platform": Color(0.36, 0.42, 0.47),
	"tray": Color(0.55, 0.45, 0.2),
}
const HAZARD_SCRIPTS := {"cable_snag": CableSnag}

var error_message: String = ""


static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2.0, (cell.y + 1) * TILE)


func build_solids(level: Dictionary, parent: Node2D) -> int:
	var solids: Dictionary = level["solids"]
	var width: int = level["width"]
	var count := 0
	for y: int in range(level["height"]):
		var x := 0
		while x < width:
			var kind: String = solids.get(Vector2i(x, y), "")
			if kind.is_empty():
				x += 1
				continue
			var start := x
			while x < width and solids.get(Vector2i(x, y), "") == kind:
				x += 1
			parent.add_child(_solid_body(kind, Rect2(start * TILE, y * TILE, (x - start) * TILE, TILE)))
			count += 1
	return count


func build_entities(level: Dictionary, parent: Node2D) -> Dictionary:
	error_message = ""
	var built := {"racks": [], "hazards": [], "coolant": [], "checkpoints": [], "exit": null}
	var anchors: Dictionary = level["anchors"]
	for task: Dictionary in level["header"]["tasks"]:
		if task["type"] != "repair":
			error_message = "Task type '%s' is not built yet." % task["type"]
			return {}
		for anchor: String in task["at"]:
			var rack := Rack.new()
			rack.task_id = task["id"]
			built["racks"].append(_add(parent, rack, anchors[anchor]))
	for hazard: Dictionary in level["hazards"]:
		if not HAZARD_SCRIPTS.has(hazard["kind"]):
			error_message = "Hazard '%s' is not built yet." % hazard["kind"]
			return {}
		built["hazards"].append(_add(parent, HAZARD_SCRIPTS[hazard["kind"]].new(), hazard["cell"]))
	for cell: Vector2i in level["coolant"]:
		built["coolant"].append(_add(parent, Coolant.new(), cell))
	var checkpoint_cells: Array = level["checkpoints"].duplicate()
	checkpoint_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	for cell: Vector2i in checkpoint_cells:
		built["checkpoints"].append(_add(parent, Checkpoint.new(), cell))
	built["exit"] = _add(parent, ExitDoor.new(), level["exit"])
	return built


func _add(parent: Node2D, node: Node2D, cell: Vector2i) -> Node2D:
	node.position = cell_to_world(cell)
	parent.add_child(node)
	return node


func _solid_body(kind: String, rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "%s_%d_%d" % [kind, int(rect.position.x) / TILE, int(rect.position.y) / TILE]
	body.position = rect.get_center()
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.one_way_collision = kind == "platform"
	body.add_child(shape)
	var view := ColorRect.new()
	view.color = SOLID_COLORS[kind]
	view.position = -rect.size / 2.0
	view.size = rect.size
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(view)
	return body
