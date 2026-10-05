extends RefCounted

var point_count: int
var spool_taken := false
var next_point := 0


func _init(points: int = 3) -> void:
	point_count = points


func collect_spool() -> bool:
	if spool_taken:
		return false
	spool_taken = true
	return true


func place(point: int) -> String:
	if next_point == point_count:
		return "already_done"
	if not spool_taken:
		return "missing_spool"
	if point != next_point:
		return "wrong_point"
	next_point += 1
	return "done" if next_point == point_count else "placed"


func capture_state() -> Dictionary:
	return {"spool_taken": spool_taken, "next_point": next_point}


func restore_state(state: Dictionary) -> void:
	spool_taken = state["spool_taken"]
	next_point = state["next_point"]
