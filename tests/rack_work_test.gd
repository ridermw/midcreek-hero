extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var path := "res://game/tasks/rack_work.gd"
	check(ResourceLoader.exists(path), "Rack assembly state exists.")
	if not ResourceLoader.exists(path):
		finish()
		return
	var script: Script = load(path)
	var rack = script.new()
	check(rack.test_work(3.0) == "missing_components", "An empty rack cannot pass testing.")
	check(rack.install("dimm") == "needs_chassis", "Memory needs an installed chassis.")
	check(rack.install("unknown") == "wrong_component", "Unknown components are not consumed.")
	check(rack.install("chassis") == "installed", "Install the chassis.")
	var chassis: Dictionary = rack.capture_state()
	check(rack.install("chassis") == "already_installed", "Duplicate chassis cannot be consumed.")
	check(rack.install("dimm") == "installed", "Memory can precede the power supply.")
	check(rack.test_work(3.0) == "missing_components", "Memory alone is insufficient.")
	check(rack.install("psu") == "installed", "Install the power supply.")
	var assembled: Dictionary = rack.capture_state()
	for delta: float in [-1.0, INF, NAN]:
		check(rack.test_work(delta) == "invalid_delta", "Reject invalid rack test time.")
	check(rack.test_work(0.75) == "working", "Testing requires a continuous hold.")
	rack.cancel()
	check(rack.test_work(0.75) == "working", "An interrupted test starts again.")
	check(rack.test_work(0.75) == "done", "A complete test certifies the rack.")
	check(rack.test_work(1.0) == "already_done", "A certified rack cannot complete twice.")
	rack.restore_state(assembled)
	check(rack.test_work(0.75) == "working", "Restoring assembled work requires testing again.")
	rack.restore_state(chassis)
	check(rack.test_work(3.0) == "missing_components", "Rollback removes later installed components.")
	check(rack.install("psu") == "installed" and rack.install("dimm") == "installed", "Rolled back components can be installed again.")
	check(chassis["installed"] == ["chassis"], "Snapshot components do not alias live state.")
	check(rack.test_work(1.5) == "done", "Restored assembly remains completable.")
	finish()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)


func finish() -> void:
	print("RACK_WORK_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
