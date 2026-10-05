extends RefCounted

const COMPONENTS: Array[String] = ["chassis", "psu", "dimm"]
const TEST_SECONDS := 1.5

var installed: Array[String] = []
var tested := false
var test_progress := 0.0


func install(component: String) -> String:
	if component not in COMPONENTS:
		return "wrong_component"
	if component in installed:
		return "already_installed"
	if component != "chassis" and "chassis" not in installed:
		return "needs_chassis"
	installed.append(component)
	return "installed"


func test_work(delta: float) -> String:
	if not is_finite(delta) or delta < 0.0:
		return "invalid_delta"
	if tested:
		return "already_done"
	if installed.size() != COMPONENTS.size():
		return "missing_components"
	test_progress = minf(TEST_SECONDS, test_progress + delta)
	if test_progress < TEST_SECONDS:
		return "working"
	tested = true
	return "done"


func cancel() -> void:
	test_progress = 0.0


func capture_state() -> Dictionary:
	return {"installed": installed.duplicate(), "tested": tested}


func restore_state(state: Dictionary) -> void:
	installed.assign(state["installed"])
	tested = state["tested"]
	cancel()
