extends RefCounted

const TEST_SECONDS := 1.5

var isolated := false
var fuse_installed := false
var continuity_passed := false
var energized := false
var test_progress := 0.0


func isolate() -> String:
	if isolated:
		return "already_isolated"
	isolated = true
	return "isolated"


func install_fuse() -> String:
	if not isolated:
		return "needs_isolation"
	if fuse_installed:
		return "already_installed"
	fuse_installed = true
	return "installed"


func test_continuity(delta: float) -> String:
	if not is_finite(delta) or delta < 0.0:
		return "invalid_delta"
	if not fuse_installed:
		return "needs_fuse"
	if continuity_passed:
		return "already_passed"
	test_progress = minf(TEST_SECONDS, test_progress + delta)
	if test_progress < TEST_SECONDS:
		return "working"
	continuity_passed = true
	return "passed"


func energize() -> String:
	if energized:
		return "already_done"
	if not continuity_passed:
		return "needs_continuity"
	energized = true
	return "done"


func cancel() -> void:
	test_progress = 0.0


func capture_state() -> Dictionary:
	return {
		"isolated": isolated, "fuse_installed": fuse_installed,
		"continuity_passed": continuity_passed, "energized": energized,
	}


func restore_state(state: Dictionary) -> void:
	isolated = state["isolated"]
	fuse_installed = state["fuse_installed"]
	continuity_passed = state["continuity_passed"]
	energized = state["energized"]
	cancel()
