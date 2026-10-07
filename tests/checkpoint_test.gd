extends SceneTree

const SlaTimer = preload("res://game/sla_timer.gd")
const TaskSystem = preload("res://game/task_system.gd")
const CheckpointManager = preload("res://game/checkpoint_manager.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var timer := SlaTimer.new()
	timer.start(200.0)
	var tasks := TaskSystem.new()
	tasks.add_task("r1", "repair", true)
	tasks.add_task("r2", "repair", true)
	var manager := CheckpointManager.new()
	manager.begin(Vector2(16, 320), timer, tasks)
	check(manager.index == -1 and manager.spawn_position == Vector2(16, 320), "begin stores the start.")
	timer.tick(50.0)
	tasks.complete("r1")
	check(manager.activate(0, Vector2(300, 320), timer, tasks), "First checkpoint activates.")
	check(not manager.activate(0, Vector2(300, 320), timer, tasks), "The same checkpoint does not activate again.")
	tasks.complete("r2")
	timer.tick(100.0)
	var spawn := manager.restore(timer, tasks)
	check(spawn == Vector2(300, 320), "restore returns the checkpoint position.")
	check(timer.remaining == 150.0, "restore sets the timer value from the checkpoint.")
	check(tasks.is_done("r1") and not tasks.is_done("r2"), "restore keeps only earlier tasks.")
	timer.tick(140.0)
	check(manager.activate(2, Vector2(900, 320), timer, tasks), "A later checkpoint can skip one.")
	check(not manager.activate(1, Vector2(600, 320), timer, tasks), "An earlier checkpoint is ignored.")
	check(manager.index == 2, "index tracks the latest checkpoint.")
	timer.tick(10.0)
	spawn = manager.restore(timer, tasks)
	check(
		spawn == Vector2(900, 320) and timer.remaining == 30.0 and timer.running,
		"restore gives at least 30 s.",
	)
	var flag: Node2D = load("res://game/entities/checkpoint.gd").new()
	flag.position = Vector2(500, 416)
	check(flag.in_range(Vector2(500, 416)), "Feet at the flag base activate it.")
	check(flag.in_range(Vector2(484, 399)), "A jump that starts beside the flag still passes through it.")
	check(flag.in_range(Vector2(510, 353)), "Feet inside the visible flag column activate it.")
	check(not flag.in_range(Vector2(500, 351)), "Feet above the flag top do not activate it.")
	check(not flag.in_range(Vector2(517, 416)), "Feet beside the flag do not activate it.")
	check(not flag.in_range(Vector2(500, 433)), "Feet below the flag base do not activate it.")
	flag.free()
	print("CHECKPOINT_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
