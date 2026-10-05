extends RefCounted

const VERIFY_SECONDS := 1.5

var diagnosed := false
var valve_open := false
var filter_installed := false
var running := false
var verify_progress := 0.0


func diagnose() -> String:
	if diagnosed:
		return "already_diagnosed"
	diagnosed = true
	return "diagnosed"


func open_valve() -> String:
	if not diagnosed:
		return "needs_diagnosis"
	if valve_open:
		return "already_open"
	valve_open = true
	return "opened"


func install_filter() -> String:
	if not valve_open:
		return "needs_valve"
	if filter_installed:
		return "already_installed"
	filter_installed = true
	return "installed"


func verify(delta: float) -> String:
	if not is_finite(delta) or delta < 0.0:
		return "invalid_delta"
	if running:
		return "already_done"
	if not filter_installed:
		return "needs_filter"
	verify_progress = minf(VERIFY_SECONDS, verify_progress + delta)
	if verify_progress < VERIFY_SECONDS:
		return "working"
	running = true
	return "done"


func cancel() -> void:
	verify_progress = 0.0


func capture_state() -> Dictionary:
	return {
		"diagnosed": diagnosed, "valve_open": valve_open,
		"filter_installed": filter_installed, "running": running,
	}


func restore_state(state: Dictionary) -> void:
	diagnosed = state["diagnosed"]
	valve_open = state["valve_open"]
	filter_installed = state["filter_installed"]
	running = state["running"]
	cancel()
