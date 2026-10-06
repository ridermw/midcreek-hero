extends RefCounted

const Rack = preload("res://game/entities/rack.gd")
const Checkpoint = preload("res://game/entities/checkpoint.gd")
const Coolant = preload("res://game/entities/coolant.gd")
const ExitDoor = preload("res://game/entities/exit_door.gd")
const CableSnag = preload("res://game/hazards/cable_snag.gd")
const ElectrifiedLiquid = preload("res://game/hazards/electrified_liquid.gd")
const HeatVent = preload("res://game/hazards/heat_vent.gd")
const MovingSnag = preload("res://game/hazards/moving_snag.gd")
const CablePort = preload("res://game/entities/cable_port.gd")
const SparkArc = preload("res://game/hazards/spark_arc.gd")
const Lift = preload("res://game/entities/lift.gd")
const SwitchPanel = preload("res://game/entities/switch_panel.gd")
const Drone = preload("res://game/hazards/drone.gd")
const Part = preload("res://game/entities/part.gd")
const RACK_TASKS: Array[String] = ["repair", "diagnose_repair", "fetch"]
const DELIVER_SECONDS := 0.5

const TILE := 32
const CEILING_LAYER := 4
const SOLID_COLORS := {
	"floor": Color(0.25, 0.29, 0.33),
	"platform": Color(0.36, 0.42, 0.47),
	"tray": Color(0.55, 0.45, 0.2),
}
const HAZARD_SCRIPTS := {"cable_snag": CableSnag, "heat_vent": HeatVent, "moving_snag": MovingSnag, "spark_arc": SparkArc, "drone": Drone, "electrified_liquid": ElectrifiedLiquid}

var error_message: String = ""
var art: RefCounted


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
			var height := TILE / 2 if kind == "tray" else TILE
			parent.add_child(_solid_body(kind, Rect2(start * TILE, y * TILE, (x - start) * TILE, height)))
			count += 1
	for cell: Vector2i in level["ladders"]:
		parent.add_child(_ladder(cell))
	return count


func build_entities(level: Dictionary, parent: Node2D) -> Dictionary:
	error_message = ""
	if art != null:
		for hazard: Dictionary in level["hazards"]:
			if hazard["kind"] == "electrified_liquid" and not art.has("hazards", "electrified-liquid"):
				error_message = "Pending artwork: missing required hazards/electrified-liquid animation."
				return {}
			if hazard["kind"] == "electrified_liquid" and art.frame_count("hazards", "electrified-liquid") != ElectrifiedLiquid.FRAME_COUNT:
				error_message = "Pending artwork: hazards/electrified-liquid requires four frames."
				return {}
	var built := {"racks": [], "parts": [], "ports": [], "switches": [], "lifts": [], "hazards": [], "liquids": [], "coolant": [], "checkpoints": [], "exit": null}
	var anchors: Dictionary = level["anchors"]
	for task: Dictionary in level["header"]["tasks"]:
		if task["type"] == "reboot":
			for i: int in range(task["at"].size()):
				var panel := SwitchPanel.new()
				panel.task_id = task["id"]
				panel.order = i + 1
				built["switches"].append(_add(parent, panel, anchors[task["at"][i]]))
			continue
		if task["type"] == "reseat":
			var port := CablePort.new()
			port.task_id = task["id"]
			built["ports"].append(_add(parent, port, anchors[task["at"][0]]))
			continue
		if task["type"] not in RACK_TASKS:
			error_message = "Task type '%s' is not built yet." % task["type"]
			return {}
		var part_kind := String(task.get("part", ""))
		for anchor: String in task["at"]:
			var rack := Rack.new()
			rack.task_id = task["id"]
			rack.kind = task["type"]
			if rack.kind == "fetch":
				rack.repair_seconds = DELIVER_SECONDS
				rack.part_kind = part_kind
			built["racks"].append(_add(parent, rack, anchors[anchor]))
		if task["type"] == "fetch":
			var part := Part.new()
			part.task_id = task["id"]
			part.kind = part_kind
			built["parts"].append(_add(parent, part, anchors[task["part_at"]]))
	for hazard: Dictionary in level["hazards"]:
		if not HAZARD_SCRIPTS.has(hazard["kind"]):
			error_message = "Hazard '%s' is not built yet." % hazard["kind"]
			return {}
		var node: Node2D = HAZARD_SCRIPTS[hazard["kind"]].new()
		if "cell_x" in node:
			node.cell_x = hazard["cell"].x
		built["hazards"].append(_add(parent, node, hazard["cell"]))
		if node is ElectrifiedLiquid:
			built["liquids"].append(node)
	for cell: Vector2i in level["lifts"]:
		built["lifts"].append(_add(parent, Lift.new(), cell))
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
	node.set("art", art)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(node)
	return node


func _ladder(cell: Vector2i) -> Node2D:
	var node := Node2D.new()
	node.name = "Ladder_%d_%d" % [cell.x, cell.y]
	node.position = Vector2(cell.x * TILE, cell.y * TILE)
	node.z_index = -1
	if art != null:
		var sprite := Sprite2D.new()
		sprite.texture = art.texture("tiles", "ladder")
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.add_child(sprite)
	else:
		var view := ColorRect.new()
		view.color = Color(0.6, 0.62, 0.65)
		view.size = Vector2(TILE, TILE)
		node.add_child(view)
	return node


func _solid_body(kind: String, rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "%s_%d_%d" % [kind, int(rect.position.x) / TILE, int(rect.position.y) / TILE]
	body.position = rect.get_center()
	body.collision_layer = 1 if kind == "platform" else 1 | CEILING_LAYER
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.one_way_collision = kind == "platform"
	body.add_child(shape)
	if art != null:
		var tiles := TextureRect.new()
		tiles.texture = art.texture("tiles", kind)
		tiles.stretch_mode = TextureRect.STRETCH_TILE
		tiles.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tiles.position = -rect.size / 2.0
		tiles.size = rect.size
		tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(tiles)
	else:
		var view := ColorRect.new()
		view.color = SOLID_COLORS[kind]
		view.position = -rect.size / 2.0
		view.size = rect.size
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(view)
	return body
