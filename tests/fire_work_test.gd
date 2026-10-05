extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var path := "res://game/tasks/fire_work.gd"
	check(ResourceLoader.exists(path), "Fire suppression state exists.")
	if not ResourceLoader.exists(path):
		finish()
		return
	var script: Script = load(path)
	var fire = script.new()
	check(fire.suppress(1.0) == "missing_extinguisher", "Suppression needs an extinguisher.")
	fire.refill()
	var filled: Dictionary = fire.capture_state()
	for delta: float in [-1.0, INF, NAN]:
		check(fire.suppress(delta) == "invalid_delta", "Reject invalid suppression time explicitly.")
		check(fire.capture_state() == filled, "Invalid time cannot create charge or alter fire.")
	check(fire.suppress(1.0) == "working", "Suppression reduces intensity over time.")
	var partial: Dictionary = fire.capture_state()
	check(is_equal_approx(partial["intensity"], 2.0), "One second removes one intensity unit.")
	check(is_equal_approx(partial["charge"], 1.0), "Suppression consumes matching charge.")
	check(fire.suppress(9.0) == "empty", "A long frame cannot use more charge than available.")
	check(is_equal_approx(fire.intensity, 1.0), "An empty extinguisher leaves remaining fire.")
	check(fire.suppress(1.0) == "empty", "Holding empty equipment cannot extinguish fire.")
	var empty: Dictionary = fire.capture_state()
	fire.refill()
	check(is_equal_approx(fire.intensity, 1.0), "Refilling does not undo suppression.")
	check(fire.suppress(1.0) == "done", "Refilled equipment finishes the fire.")
	check(fire.suppress(1.0) == "already_done", "Extinguished fire cannot consume more charge.")
	fire.restore_state(empty)
	check(fire.suppress(1.0) == "empty", "Rollback restores depleted charge and active fire.")
	fire.restore_state(partial)
	check(is_equal_approx(fire.intensity, 2.0) and is_equal_approx(fire.charge, 1.0), "Partial suppression and resource use restore together.")
	fire.restore_state(filled)
	check(fire.suppress(2.0) == "empty", "Restored full equipment has its original capacity.")
	fire.refill()
	check(fire.suppress(1.0) == "done", "The restored fire remains completable.")
	finish()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)


func finish() -> void:
	print("FIRE_WORK_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
