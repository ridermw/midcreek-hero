extends RefCounted

const DRAIN_SECONDS := 3.0

var valve_closed := false
var seal_installed := false
var drained_seconds := 0.0


func close_valve() -> String:
	if valve_closed:
		return "already_closed"
	valve_closed = true
	return "closed"


func install_seal() -> String:
	if not valve_closed:
		return "needs_valve"
	if seal_installed:
		return "already_installed"
	seal_installed = true
	return "installed"


func drain(delta: float) -> String:
	if not is_finite(delta) or delta < 0.0:
		return "invalid_delta"
	if not seal_installed:
		return "needs_seal"
	if drained_seconds >= DRAIN_SECONDS:
		return "already_done"
	drained_seconds = minf(DRAIN_SECONDS, drained_seconds + delta)
	return "done" if drained_seconds >= DRAIN_SECONDS else "working"


func capture_state() -> Dictionary:
	return {
		"valve_closed": valve_closed, "seal_installed": seal_installed,
		"drained_seconds": drained_seconds,
	}


func restore_state(state: Dictionary) -> void:
	valve_closed = state["valve_closed"]
	seal_installed = state["seal_installed"]
	drained_seconds = state["drained_seconds"]
