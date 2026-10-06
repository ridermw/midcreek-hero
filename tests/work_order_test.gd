extends SceneTree

const Inventory = preload("res://game/tasks/work_inventory.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var path := "res://game/tasks/work_order.gd"
	check(ResourceLoader.exists(path), "Task interaction adapter exists.")
	if not ResourceLoader.exists(path):
		finish()
		return
	var script: Script = load(path)
	var bag := Inventory.new()
	var cable = script.new({"id": "c", "type": "run_cable", "sites": [[2, 2], [4, 2], [8, 2]], "resources": [{"kind": "spool", "cell": [1, 2]}]}, bag)
	check(cable.prompt(0)["status"].contains("spool"), "Blocked cable prompt identifies the resource.")
	check(not cable.step(0, true, true, false, false, 0.1)["completed"], "Missing spool prevents placement.")
	bag.take("c:0")
	check(cable.prompt(0)["action"] == "repair", "Carried spool enables source connection.")
	cable.step(0, true, true, false, false, 0.1)
	check(bag.carried.is_empty() and not bag.available("c:0"), "Source connection consumes exactly one spool.")
	check(cable.prompt(2)["status"].contains("2"), "Wrong cable point names the next point.")
	cable.step(1, true, true, false, false, 0.1)
	check(cable.step(2, true, true, false, false, 0.1)["completed"], "Destination emits completion.")
	check(not cable.step(2, true, true, false, false, 0.1)["completed"], "Completion is emitted once.")
	var rack = script.new({"id": "r", "type": "assemble_rack", "sites": [[2, 2]], "resources": [{"kind": "chassis", "cell": [1, 2]}, {"kind": "psu", "cell": [4, 2]}, {"kind": "dimm", "cell": [6, 2]}]}, bag)
	bag.take("r:1")
	rack.step(0, true, true, false, false, 0.1)
	check(bag.carried == "r:1", "Blocked assembly does not consume a supply before the chassis.")
	for index: int in [0, 1, 2]:
		bag.take("r:%d" % index)
		rack.step(0, true, true, false, false, 0.1)
	check(rack.prompt(0)["action"] == "diagnose" and rack.prompt(0)["intent"] == "hold", "Assembled rack requests its actual test action.")
	check(not rack.step(0, true, false, false, false, 2.0)["completed"], "Repair cannot replace the requested diagnostic action.")
	check(rack.step(0, false, false, true, false, 1.5)["completed"], "Holding diagnose certifies the assembled rack.")
	var power = script.new({"id": "p", "type": "restore_power", "sites": [[2, 2]], "resources": [{"kind": "fuse", "cell": [1, 2]}]}, bag)
	var snapshot: Dictionary = power.capture_state()
	bag.take("p:0")
	power.step(0, true, true, false, false, 0.1)
	power.step(0, true, true, false, false, 0.1)
	check(bag.carried.is_empty(), "Isolated power installation consumes its fuse.")
	check(power.step(0, false, false, true, false, 1.5)["prompt"]["action"] == "repair", "Continuity completion requests energize.")
	check(power.step(0, true, true, false, false, 0.1)["completed"], "Energize completes the branch.")
	power.restore_state(snapshot)
	check(not power.done and power.prompt(0)["text"].contains("Isolate"), "Restoring task progress restores its instruction.")
	for kind: String in ["extinguish_fire", "restore_cooling", "contain_leak"]:
		var resource: String = {"extinguish_fire": "extinguisher", "restore_cooling": "filter", "contain_leak": "seal"}[kind]
		var work = script.new({"id": kind, "type": kind, "sites": [[2, 2], [5, 2]], "resources": [{"kind": resource, "cell": [1, 2]}]}, bag)
		bag.take(kind + ":0")
		if kind == "extinguish_fire":
			work.step(0, true, false, false, false, 2.0)
			check(work.prompt(0)["status"].contains("Refill"), "Empty fire tool requests its refill station.")
			check(work.collect(0) == "refilled", "Consumed extinguisher source becomes a refill station.")
			check(work.step(0, true, false, false, false, 1.0)["completed"], "Refill enables remaining suppression.")
		elif kind == "restore_cooling":
			work.step(0, false, false, true, true, 0.1)
			work.step(1, true, true, false, false, 0.1)
			work.step(0, true, true, false, false, 0.1)
			check(work.step(0, true, false, false, false, 1.5)["completed"], "Cooling uses diagnosis, valve, filter, then verification.")
		else:
			work.step(0, true, true, false, false, 0.1)
			work.step(0, true, true, false, false, 0.1)
			check(work.step(1, true, false, false, false, 3.0)["completed"], "Leak uses isolation, seal, and a separate drain.")
		work.cancel()
	finish()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)


func finish() -> void:
	print("WORK_ORDER_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
