extends SceneTree

const LEVEL = preload("res://game/level.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var tasks := [
		{"id": "cable", "type": "run_cable", "required": true, "sites": [[8, 3], [12, 3], [16, 3]], "resources": [{"kind": "spool", "cell": [4, 3]}]},
		{"id": "cool", "type": "restore_cooling", "required": true, "sites": [[24, 3], [28, 3]], "resources": [{"kind": "filter", "cell": [20, 3]}], "effect_cells": [[32, 3]]},
		{"id": "leak", "type": "contain_leak", "required": true, "sites": [[40, 3], [44, 3]], "resources": [{"kind": "seal", "cell": [36, 3]}], "effect_cells": [[48, 3]]},
	]
	var row := ".".repeat(56)
	for entry: Array in [[0, "P"], [2, "C"], [18, "C"], [34, "C"], [32, "v"], [48, "~"], [55, "E"]]:
		row[entry[0]] = entry[1]
	var header := {"name": "Work runtime", "background": "cold-aisle", "music": "cold-aisle", "par_seconds": 100, "sla_seconds": 200, "tasks": tasks}
	var file := FileAccess.open("user://work-runtime.level", FileAccess.WRITE)
	file.store_string(JSON.stringify(header) + "\n---\n" + (".".repeat(56) + "\n").repeat(3) + row + "\n" + "#".repeat(56))
	file.close()
	var level := LEVEL.instantiate()
	level.level_path = "user://work-runtime.level"
	root.add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	check(level.error_message.is_empty(), "Coordinate work loads into the real level: " + level.error_message)
	if level.error_message.is_empty():
		check(level.entities["work"].size() == 3 and level.entities["work_resources"].size() == 3, "Builder creates task owners and resource sources.")
		var before: Dictionary = level.capture_state()
		act(level, 4, "repair")
		check(level.work_inventory.carried == "cable:0", "Selected source puts its task resource in the shared slot.")
		act(level, 8, "repair")
		check(level.work_inventory.carried.is_empty(), "Connecting source consumes only its spool.")
		var partial: Dictionary = level.capture_state()
		act(level, 12, "repair")
		act(level, 16, "repair")
		check(level.tasks.is_done("cable"), "Last cable point completes its registry task.")
		level.restore_state(partial)
		check(level.entities["work"][0].order.unit.next_point == 1, "Restoring partial cable removes later anchors.")
		level.restore_state(before)
		check(level.work_inventory.available("cable:0"), "Earlier checkpoint returns consumed spool to source.")
		act(level, 20, "repair")
		act(level, 24, "diagnose")
		act(level, 28, "repair")
		act(level, 24, "repair")
		hold(level, 24, "repair", 100)
		check(level.tasks.is_done("cool"), "Cooling stages complete through level input.")
		var vent = level.entities["hazards"][0]
		vent.advance(10.0)
		check(not vent.active, "Cooling completion disables the bound heat source across later cycles.")
		level.restore_state(before)
		vent.advance(10.0)
		check(vent.enabled, "Earlier checkpoint restores cooling's bound hazard.")
		act(level, 36, "repair")
		act(level, 40, "repair")
		act(level, 40, "repair")
		hold(level, 44, "repair", 60)
		var drained: float = level.entities["work"][2].order.unit.drained_seconds
		act(level, 44, "")
		check(drained > 0.9 and level.entities["work"][2].order.unit.drained_seconds == drained, "Drain progress survives interruption.")
		hold(level, 44, "repair", 130)
		check(not level.entities["liquids"][0].active, "Completed drain disables only its bound liquid.")
		level.restore_state(before)
		check(level.entities["liquids"][0].active, "Checkpoint rollback restores dangerous liquid.")
	level.queue_free()
	await process_frame
	tasks = [
		{"id": "rack", "type": "assemble_rack", "required": true, "sites": [[8, 3]], "resources": [{"kind": "chassis", "cell": [4, 3]}, {"kind": "psu", "cell": [12, 3]}, {"kind": "dimm", "cell": [16, 3]}]},
		{"id": "fire", "type": "extinguish_fire", "required": true, "sites": [[24, 3]], "resources": [{"kind": "extinguisher", "cell": [20, 3]}], "effect_cells": [[28, 3]]},
		{"id": "power", "type": "restore_power", "required": true, "sites": [[40, 3]], "resources": [{"kind": "fuse", "cell": [36, 3]}]},
	]
	row[32] = "."
	row[48] = "."
	row[28] = "f"
	header["tasks"] = tasks
	file = FileAccess.open("user://work-runtime.level", FileAccess.WRITE)
	file.store_string(JSON.stringify(header) + "\n---\n" + (".".repeat(56) + "\n").repeat(3) + row + "\n" + "#".repeat(56))
	file.close()
	level = LEVEL.instantiate()
	level.level_path = "user://work-runtime.level"
	root.add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	check(level.error_message.is_empty(), "Rack, fire, and power load into the real level.")
	if level.error_message.is_empty():
		act(level, 12, "repair")
		act(level, 8, "repair")
		check(level.work_inventory.carried == "rack:1" and level.hud.prompt["status"].contains("chassis"), "Blocked rack keeps its resource and owns its prerequisite prompt.")
		act(level, 4, "repair")
		check(level.work_inventory.available("rack:1"), "Explicit exchange returns the previous resource to its source.")
		act(level, 8, "repair")
		for column: int in [12, 16]:
			act(level, column, "repair")
			act(level, 8, "repair")
		hold(level, 8, "diagnose", 50)
		act(level, 8, "")
		hold(level, 8, "diagnose", 50)
		check(not level.tasks.is_done("rack"), "Interrupted rack tests discard only their current hold.")
		hold(level, 8, "diagnose", 100)
		check(level.tasks.is_done("rack"), "Installed components survive interruption and permit the final test.")
		act(level, 20, "repair")
		hold(level, 24, "repair", 60)
		var partial: Dictionary = level.capture_state()
		check(level.entities["work"][1].order.unit.intensity < 2.1, "Held action partially suppresses fire.")
		hold(level, 24, "repair", 90)
		check(level.hud.prompt["status"].contains("Refill") and level.entities["hazards"][0].active, "Empty charge preserves remaining fire and names refill.")
		act(level, 20, "repair")
		hold(level, 24, "repair", 100)
		check(level.tasks.is_done("fire") and not level.entities["hazards"][0].active, "Refill permits completion and disables bound fire.")
		level.restore_state(partial)
		check(level.entities["hazards"][0].active and level.entities["work"][1].order.unit.charge > 0.9, "Rollback restores fire intensity and available charge together.")
		act(level, 36, "repair")
		act(level, 40, "repair")
		act(level, 40, "repair")
		hold(level, 40, "diagnose", 100)
		check(level.hud.prompt["action"] == "repair" and not level.tasks.is_done("power"), "Completed continuity requests energize without applying it.")
		act(level, 40, "repair")
		check(level.tasks.is_done("power"), "Explicit energize completes the power branch.")
		var station = level.entities["work"][0]
		station.order.done = false
		station.sites[0] = Vector2(24 * 32 + 16, 128)
		station.order.unit.installed.clear()
		act(level, 24, "repair")
		check(level.hud.prompt["status"].contains("chassis"), "A selected blocked station keeps its prompt when another task overlaps its range.")
	level.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://work-runtime.level"))
	print("WORK_RUNTIME_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func act(level: Node, column: int, action: String) -> void:
	level.player.position = Vector2(column * 32 + 16, 128)
	level.use_action_override = true
	level.action_override = {}
	level.step(1.0 / 60.0)
	if not action.is_empty():
		level.action_override = {action: true}
		level.step(1.0 / 60.0)


func hold(level: Node, column: int, action: String, ticks: int) -> void:
	act(level, column, "")
	level.action_override = {action: true}
	for tick: int in range(ticks):
		level.step(1.0 / 60.0)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
