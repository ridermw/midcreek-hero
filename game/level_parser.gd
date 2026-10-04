extends RefCounted

const TaskSystem = preload("res://game/task_system.gd")

const SOLIDS := {"#": "floor", "=": "platform", "T": "tray"}
const HAZARDS := {
	"s": "cable_snag",
	"m": "moving_snag",
	"v": "heat_vent",
	"k": "spark_arc",
	"d": "drone",
}
const RESERVED_UPPER: Array[String] = ["C", "E", "P", "T"]
const HEADER_STRINGS: Array[String] = ["name", "music", "background"]
const SINGLE_ANCHOR_TYPES: Array[String] = ["diagnose_repair", "fetch", "reseat"]
const MAX_CHECKPOINTS := 3
const NO_CELL := Vector2i(-1, -1)

var error_message: String = ""


func parse(text: String, source: String) -> Dictionary:
	error_message = ""
	var lines := text.replace("\r\n", "\n").split("\n")
	var separator := lines.find("---")
	if separator < 0:
		return _fail(source, 1, "Missing '---' line between header and grid.")
	var json := JSON.new()
	if json.parse("\n".join(lines.slice(0, separator))) != OK:
		return _fail(source, json.get_error_line(), "Invalid header JSON: " + json.get_error_message())
	if not json.data is Dictionary:
		return _fail(source, 1, "Header must be a JSON object.")
	var header: Dictionary = json.data
	var header_error := _check_header(header)
	if not header_error.is_empty():
		return _fail(source, 1, header_error)
	var rows: Array[String] = []
	for i: int in range(separator + 1, lines.size()):
		rows.append(lines[i])
	while not rows.is_empty() and rows.back().is_empty():
		rows.pop_back()
	if rows.is_empty():
		return _fail(source, separator + 2, "Grid is empty.")
	var level := {
		"source": source,
		"header": header,
		"width": rows[0].length(),
		"height": rows.size(),
		"solids": {},
		"ladders": [],
		"lifts": [],
		"player_start": NO_CELL,
		"exit": NO_CELL,
		"checkpoints": [],
		"coolant": [],
		"hazards": [],
		"anchors": {},
	}
	for y: int in range(rows.size()):
		var line_number := separator + 2 + y
		var row := rows[y]
		if row.length() != level["width"]:
			return _fail(
				source,
				line_number,
				"Row width %d differs from first row width %d." % [row.length(), level["width"]],
			)
		for x: int in range(row.length()):
			var problem := _place(level, row[x], Vector2i(x, y))
			if not problem.is_empty():
				return _fail(source, line_number, "%s (column %d)" % [problem, x + 1])
	var grid_error := _check_grid(level)
	if grid_error.is_empty():
		grid_error = _check_tasks(level)
	if not grid_error.is_empty():
		return _fail(source, 1, grid_error)
	return level


func _check_header(header: Dictionary) -> String:
	for key: String in HEADER_STRINGS:
		if not header.get(key) is String or String(header[key]).is_empty():
			return "Header key '%s' must be a non-empty string." % key
	for key: String in ["sla_seconds", "par_seconds"]:
		var value: Variant = header.get(key)
		if not (value is float or value is int):
			return "Header key '%s' must be a number." % key
	if float(header["par_seconds"]) <= 0.0 or float(header["par_seconds"]) >= float(header["sla_seconds"]):
		return "par_seconds must be above 0 and below sla_seconds."
	if not header.get("tasks") is Array or header["tasks"].is_empty():
		return "Header key 'tasks' must be a non-empty array."
	return ""


func _place(level: Dictionary, symbol: String, cell: Vector2i) -> String:
	if symbol == ".":
		return ""
	if SOLIDS.has(symbol):
		level["solids"][cell] = SOLIDS[symbol]
	elif symbol == "|":
		level["ladders"].append(cell)
	elif symbol == "l":
		level["lifts"].append(cell)
	elif symbol == "P" or symbol == "E":
		var key := "player_start" if symbol == "P" else "exit"
		if level[key] != NO_CELL:
			return "Second '%s' marker." % symbol
		level[key] = cell
	elif symbol == "C":
		level["checkpoints"].append(cell)
	elif symbol == "h":
		level["coolant"].append(cell)
	elif HAZARDS.has(symbol):
		level["hazards"].append({"kind": HAZARDS[symbol], "cell": cell})
	elif _is_anchor(symbol):
		if level["anchors"].has(symbol):
			return "Anchor '%s' appears more than once." % symbol
		level["anchors"][symbol] = cell
	else:
		return "Unknown legend character '%s'." % symbol
	return ""


func _is_anchor(symbol: String) -> bool:
	var code := symbol.unicode_at(0)
	return code >= 65 and code <= 90 and symbol not in RESERVED_UPPER


func _check_grid(level: Dictionary) -> String:
	if level["player_start"] == NO_CELL:
		return "Missing player start 'P'."
	if level["exit"] == NO_CELL:
		return "Missing exit 'E'."
	if level["checkpoints"].size() > MAX_CHECKPOINTS:
		return "More than %d checkpoints." % MAX_CHECKPOINTS
	return ""


func _check_tasks(level: Dictionary) -> String:
	var anchors: Dictionary = level["anchors"]
	var used := {}
	var task_ids := {}
	var required := 0
	for task: Variant in level["header"]["tasks"]:
		if not task is Dictionary:
			return "Each task must be an object."
		var id: Variant = task.get("id")
		var type: Variant = task.get("type")
		var at: Variant = task.get("at")
		if (
			not id is String
			or not type is String
			or not task.get("required") is bool
			or not at is Array
			or at.is_empty()
		):
			return "Each task needs string id, string type, bool required, and a non-empty 'at' array."
		if id.is_empty():
			return "Task id must not be empty."
		if task_ids.has(id):
			return "Duplicate task id: " + id
		task_ids[id] = true
		if task.has("label") and not task["label"] is String:
			return "Task '%s' label must be a string." % id
		if type not in TaskSystem.TYPES:
			return "Task '%s' has unknown type '%s'." % [id, type]
		var references: Array = at.duplicate()
		if type == "fetch":
			if not task.get("part_at") is String:
				return "Fetch task '%s' needs 'part_at'." % id
			references.append(task["part_at"])
		if type in SINGLE_ANCHOR_TYPES and at.size() != 1:
			return "Task '%s' needs exactly 1 'at' anchor." % id
		if type == "reboot" and at.size() != 3:
			return "Reboot task '%s' needs 3 'at' anchors." % id
		for anchor: Variant in references:
			if not anchor is String or not anchors.has(anchor):
				return "Task '%s' references missing anchor '%s'." % [id, anchor]
			if used.has(anchor):
				return "Anchor '%s' is used by more than one task reference." % anchor
			used[anchor] = true
		if task["required"]:
			required += 1
	if required == 0:
		return "At least one task must be required."
	for anchor: String in anchors:
		if not used.has(anchor):
			return "Anchor '%s' is not used by any task." % anchor
	return ""


func _fail(source: String, line: int, message: String) -> Dictionary:
	error_message = "%s:%d: %s" % [source, line, message]
	return {}
