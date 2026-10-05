extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for kind: String in ["cooling", "leak", "power"]:
		var path := "res://game/tasks/%s_work.gd" % kind
		check(ResourceLoader.exists(path), kind + " work state exists.")
		if not ResourceLoader.exists(path):
			continue
		var script: Script = load(path)
		match kind:
			"cooling": test_cooling(script.new())
			"leak": test_leak(script.new())
			"power": test_power(script.new())
	print("SERVICE_WORK_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func test_cooling(work: RefCounted) -> void:
	check(work.open_valve() == "needs_diagnosis", "Cooling valve needs diagnosis.")
	check(work.install_filter() == "needs_valve", "Filter needs an open valve.")
	check(work.verify(9.0) == "needs_filter", "Verification needs a filter.")
	var initial: Dictionary = work.capture_state()
	check(work.diagnose() == "diagnosed", "Diagnosis identifies the fault.")
	check(work.diagnose() == "already_diagnosed", "Diagnosis is not duplicated.")
	check(work.open_valve() == "opened", "Open the diagnosed valve.")
	check(work.open_valve() == "already_open", "Repeated valve input retains progress.")
	var valve: Dictionary = work.capture_state()
	check(work.install_filter() == "installed", "Install the filter.")
	check(work.install_filter() == "already_installed", "Do not consume a second filter.")
	for delta: float in [-1.0, INF, NAN]:
		check(work.verify(delta) == "invalid_delta", "Reject invalid cooling time.")
	check(work.verify(0.75) == "working", "Cooling requires continuous verification.")
	work.cancel()
	check(work.verify(0.75) == "working", "Interruption clears verification time.")
	check(work.verify(0.75) == "done", "Verification starts cooling.")
	var complete: Dictionary = work.capture_state()
	check(work.verify(9.0) == "already_done", "Cooling completion is emitted once.")
	work.restore_state(valve)
	check(work.verify(9.0) == "needs_filter", "Rollback removes the later filter.")
	check(work.install_filter() == "installed", "Restored valve accepts the returned filter.")
	work.restore_state(complete)
	check(work.verify(1.0) == "already_done", "Completed cooling restores running state.")
	work.restore_state(initial)
	check(work.open_valve() == "needs_diagnosis", "Initial checkpoint undoes diagnosis.")


func test_leak(work: RefCounted) -> void:
	check(work.install_seal() == "needs_valve", "Seal needs isolation.")
	check(work.drain(9.0) == "needs_seal", "An unsealed leak cannot drain.")
	var initial: Dictionary = work.capture_state()
	check(work.close_valve() == "closed", "Close the supply.")
	check(work.close_valve() == "already_closed", "Closing is idempotent.")
	check(work.install_seal() == "installed", "Install the seal.")
	check(work.install_seal() == "already_installed", "Do not consume another seal.")
	for delta: float in [-1.0, INF, NAN]:
		check(work.drain(delta) == "invalid_delta", "Reject invalid drainage time.")
	check(work.drain(1.0) == "working", "Drainage progresses over time.")
	var partial: Dictionary = work.capture_state()
	check(work.drain(2.0) == "done", "Drainage persists between interactions.")
	check(work.drain(1.0) == "already_done", "Drain completion is emitted once.")
	work.restore_state(partial)
	check(work.drain(1.0) == "working", "Partial checkpoint restores remaining drainage.")
	check(work.drain(1.0) == "done", "Partial checkpoint remains completable.")
	work.restore_state(initial)
	check(work.install_seal() == "needs_valve", "Rollback reopens supply and removes seal.")
	check(work.drain(9.0) == "needs_seal", "Rollback does not leave a drained effect.")


func test_power(work: RefCounted) -> void:
	check(work.install_fuse() == "needs_isolation", "A live branch rejects fuse replacement.")
	check(work.test_continuity(9.0) == "needs_fuse", "Continuity needs a fuse.")
	check(work.energize() == "needs_continuity", "An untested branch stays off.")
	var initial: Dictionary = work.capture_state()
	check(work.isolate() == "isolated", "Isolate the branch.")
	check(work.isolate() == "already_isolated", "Isolation is idempotent.")
	check(work.install_fuse() == "installed", "Replace the isolated fuse.")
	check(work.install_fuse() == "already_installed", "Do not consume a second fuse.")
	var installed: Dictionary = work.capture_state()
	for delta: float in [-1.0, INF, NAN]:
		check(work.test_continuity(delta) == "invalid_delta", "Reject invalid continuity time.")
	check(work.test_continuity(0.75) == "working", "Continuity requires a continuous test.")
	check(work.energize() == "needs_continuity", "Partial testing cannot energize.")
	work.cancel()
	check(work.test_continuity(0.75) == "working", "Interrupting continuity resets its timer.")
	check(work.test_continuity(0.75) == "passed", "Full test establishes continuity.")
	check(work.energize() == "done", "Energize the tested branch.")
	check(work.energize() == "already_done", "Repeated input cannot complete twice.")
	var complete: Dictionary = work.capture_state()
	work.restore_state(installed)
	check(work.energize() == "needs_continuity", "Rollback removes later continuity and power.")
	check(work.test_continuity(1.5) == "passed" and work.energize() == "done", "Restored fuse can be tested and energized.")
	work.restore_state(complete)
	check(work.energize() == "already_done", "Completed checkpoint restores power.")
	work.restore_state(initial)
	check(work.install_fuse() == "needs_isolation", "Initial checkpoint undoes isolation.")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)
