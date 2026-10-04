extends RefCounted

signal task_completed(id: String)
signal all_required_done

const TYPES: Array[String] = ["repair", "diagnose_repair", "fetch", "reseat", "reboot"]
const TYPE_LABELS := {
	"repair": "Repair rack",
	"diagnose_repair": "Diagnose and repair",
	"fetch": "Fetch part",
	"reseat": "Reseat cable",
	"reboot": "Reboot switch",
}

var _tasks: Dictionary[String, Dictionary] = {}
var _order: Array[String] = []
var _announced: bool = false


func add_task(id: String, type: String, required: bool, label: String = "") -> String:
	if id.is_empty():
		return "Task id must not be empty."
	if _tasks.has(id):
		return "Duplicate task id: " + id
	if type not in TYPES:
		return "Unknown task type: " + type
	if label.is_empty():
		label = "%s %s" % [TYPE_LABELS[type], id.to_upper()]
	_tasks[id] = {"id": id, "type": type, "required": required, "label": label, "done": false}
	_order.append(id)
	return ""


func complete(id: String) -> bool:
	if not _tasks.has(id) or _tasks[id]["done"]:
		return false
	_tasks[id]["done"] = true
	task_completed.emit(id)
	if not _announced and required_done():
		_announced = true
		all_required_done.emit()
	return true


func is_done(id: String) -> bool:
	return _tasks.has(id) and bool(_tasks[id]["done"])


func required_done() -> bool:
	for id: String in _order:
		if _tasks[id]["required"] and not _tasks[id]["done"]:
			return false
	return true


func completed_ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in _order:
		if _tasks[id]["done"]:
			result.append(id)
	return result


func restore(done_ids: Array[String]) -> void:
	for id: String in _order:
		_tasks[id]["done"] = id in done_ids
	_announced = required_done()


func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in _order:
		result.append(_tasks[id].duplicate())
	return result
