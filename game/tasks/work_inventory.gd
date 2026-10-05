extends RefCounted

var items: Dictionary[String, String] = {}
var carried := ""
var consumed: Array[String] = []


func register_item(id: String, kind: String) -> String:
	if id.is_empty() or kind.is_empty():
		return "Resource identity and kind must not be empty."
	if items.has(id):
		return "Duplicate resource: " + id
	items[id] = kind
	return ""


func available(id: String) -> bool:
	return items.has(id) and id != carried and id not in consumed


func take(id: String) -> String:
	if not items.has(id):
		return "unknown_item"
	if id in consumed:
		return "consumed"
	if id == carried:
		return "already_carried"
	var swapped := not carried.is_empty()
	carried = id
	return "swapped" if swapped else "taken"


func consume(id: String) -> String:
	if not items.has(id):
		return "unknown_item"
	if carried != id:
		return "wrong_item"
	consumed.append(id)
	carried = ""
	return "consumed"


func capture_state() -> Dictionary:
	return {"carried": carried, "consumed": consumed.duplicate()}


func restore_state(state: Dictionary) -> void:
	carried = state["carried"]
	consumed.assign(state["consumed"])
