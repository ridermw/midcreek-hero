extends SceneTree

const TaskSystem = preload("res://game/task_system.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var tasks := TaskSystem.new()
	var events := {"completed": [], "all": 0}
	tasks.task_completed.connect(func(id: String) -> void: events["completed"].append(id))
	tasks.all_required_done.connect(func() -> void: events["all"] += 1)
	check(tasks.add_task("r1", "repair", true, "Repair R1") == "", "Adds a required repair task.")
	check(tasks.add_task("f1", "fetch", true) == "", "Adds a required fetch task.")
	check(tasks.add_task("o1", "reseat", false) == "", "Adds an optional task.")
	check(tasks.add_task("r1", "repair", true) == "Duplicate task id: r1", "Rejects duplicate ids.")
	check(tasks.add_task("x1", "dance", true) == "Unknown task type: dance", "Rejects unknown types.")
	check(tasks.add_task("", "repair", true) == "Task id must not be empty.", "Rejects empty ids.")
	check(not tasks.complete("missing"), "Unknown ids do not complete.")
	check(tasks.complete("r1"), "complete returns true the first time.")
	check(events["completed"] == ["r1"], "task_completed carries the id.")
	check(not tasks.required_done(), "One required task is still open.")
	check(tasks.complete("o1") and events["all"] == 0, "Optional tasks do not open the exit.")
	check(tasks.complete("f1") and events["all"] == 1, "Last required task emits all_required_done.")
	check(not tasks.complete("f1"), "A done task does not complete again.")
	var expected: Array[String] = ["r1", "f1", "o1"]
	check(tasks.completed_ids() == expected, "completed_ids follows add order.")
	tasks.restore(["r1"])
	check(
		tasks.is_done("r1") and not tasks.is_done("f1") and not tasks.is_done("o1"),
		"restore sets the done state exactly.",
	)
	check(not tasks.required_done(), "restore can reopen required work.")
	check(tasks.complete("f1") and events["all"] == 2, "all_required_done emits again after restore.")
	var entries := tasks.entries()
	check(entries.size() == 3 and entries[0]["label"] == "Repair R1", "entries keep custom labels.")
	check(entries[1]["label"] == "Fetch part F1", "entries build a default label.")
	print("TASK_SYSTEM_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
