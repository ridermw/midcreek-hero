extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var path := "res://game/tasks/cable_work.gd"
	check(ResourceLoader.exists(path), "Cable installation state exists.")
	if not ResourceLoader.exists(path):
		finish()
		return
	var script: Script = load(path)
	var cable = script.new(4)
	check(cable.place(0) == "missing_spool", "Source needs its spool.")
	check(cable.collect_spool(), "Collect the available spool.")
	check(not cable.collect_spool(), "Collection cannot duplicate the spool.")
	var carried: Dictionary = cable.capture_state()
	check(cable.place(1) == "wrong_point", "An anchor cannot precede the source.")
	check(cable.capture_state() == carried, "Wrong order does not consume the spool.")
	check(cable.place(0) == "placed", "Source begins installation.")
	check(not cable.collect_spool(), "The installed spool cannot be collected again.")
	var partial: Dictionary = cable.capture_state()
	check(cable.place(0) == "wrong_point", "A repeated source cannot advance placement.")
	check(cable.place(-1) == "wrong_point", "A negative index cannot advance placement.")
	check(cable.place(4) == "wrong_point", "An out of range point cannot complete work.")
	check(cable.place(1) == "placed", "Secure the first anchor.")
	check(cable.place(2) == "placed", "Secure the second anchor.")
	check(cable.place(3) == "done", "The destination completes installation.")
	var complete: Dictionary = cable.capture_state()
	check(cable.place(3) == "already_done", "Repeated completion has no effect.")
	check(cable.capture_state() == complete, "Repeated completion preserves state.")
	cable.restore_state(partial)
	check(cable.place(2) == "wrong_point", "Restoring partial work restores its next anchor.")
	check(cable.place(1) == "placed", "Restored installation continues without another spool.")
	cable.restore_state(carried)
	check(cable.place(0) == "placed", "Restore the collected spool before installation.")
	check(carried == {"spool_taken": true, "next_point": 0}, "Later placement does not mutate a snapshot.")
	var fresh = script.new(3)
	var initial: Dictionary = fresh.capture_state()
	fresh.collect_spool()
	fresh.place(0)
	fresh.restore_state(initial)
	check(fresh.place(0) == "missing_spool", "Rollback restores source resource availability.")
	check(fresh.collect_spool(), "The restored spool can be collected.")
	check(fresh.place(0) == "placed" and fresh.place(1) == "placed" and fresh.place(2) == "done", "A restored minimum cable remains completable.")
	fresh.restore_state({"spool_taken": true, "next_point": 3})
	check(fresh.place(2) == "already_done", "Completed snapshot restores completion.")
	finish()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)


func finish() -> void:
	print("CABLE_WORK_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
