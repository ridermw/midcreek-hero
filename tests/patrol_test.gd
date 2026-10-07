extends SceneTree

const Patrol = preload("res://game/hazards/patrol.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var patrol := Patrol.new(100.0, 60.0, 140.0, 40.0)
	check(patrol.x == 100.0 and patrol.direction == 1.0, "A patrol starts at its origin moving right.")
	check(is_equal_approx(patrol.step(0.5), 120.0), "A patrol moves at its speed.")
	check(patrol.step(1.0) == 140.0 and patrol.direction == -1.0, "A patrol stops at its right bound and reverses.")
	check(is_equal_approx(patrol.step(0.5), 120.0), "A reversed patrol moves left.")
	patrol.step(5.0)
	check(patrol.x == 60.0 and patrol.direction == 1.0, "A patrol stops at its left bound and reverses.")
	var inside := true
	for i: int in range(600):
		patrol.step(1.0 / 60.0)
		inside = inside and patrol.x >= 60.0 and patrol.x <= 140.0
	check(inside, "A patrol never leaves its bounds.")
	patrol.reset()
	check(patrol.x == 100.0 and patrol.direction == 1.0, "Reset restores the authored origin and direction.")
	var fixed := Patrol.new(100.0, 100.0, 100.0, 40.0)
	check(fixed.step(1.0) == 100.0, "A zero span patrol stays at its origin.")
	print("PATROL_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
