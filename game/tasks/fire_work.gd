extends RefCounted

const CAPACITY := 2.0

var equipped := false
var charge := 0.0
var intensity := 3.0


func refill() -> void:
	equipped = true
	charge = CAPACITY


func suppress(delta: float) -> String:
	if not is_finite(delta) or delta < 0.0:
		return "invalid_delta"
	if intensity <= 0.0:
		return "already_done"
	if not equipped:
		return "missing_extinguisher"
	var used := minf(delta, minf(charge, intensity))
	charge -= used
	intensity -= used
	if intensity <= 0.0:
		return "done"
	return "empty" if charge <= 0.0 else "working"


func capture_state() -> Dictionary:
	return {"equipped": equipped, "charge": charge, "intensity": intensity}


func restore_state(state: Dictionary) -> void:
	equipped = state["equipped"]
	charge = state["charge"]
	intensity = state["intensity"]
