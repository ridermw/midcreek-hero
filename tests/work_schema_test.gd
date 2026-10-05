extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var path := "res://game/tasks/work_schema.gd"
	check(ResourceLoader.exists(path), "Expansion task schema exists.")
	if not ResourceLoader.exists(path):
		finish()
		return
	var schema: Script = load(path)
	var level := {"width": 20, "height": 4, "solids": {}, "hazards": []}
	for x: int in range(20):
		level["solids"][Vector2i(x, 3)] = "floor"
	var cable := {
		"type": "run_cable", "sites": [[3, 2], [6, 2], [10, 2]],
		"resources": [{"kind": "spool", "cell": [1, 2]}],
	}
	check(schema.validate(cable, level).is_empty(), "An ordered cable has one source resource.")
	for change: Dictionary in [
		{"sites": [[3, 2], [10, 2]]}, {"sites": [[3, 2], [3, 2], [10, 2]]},
		{"sites": [[3.5, 2], [6, 2], [10, 2]]},
		{"sites": [[20, 2], [6, 2], [10, 2]]},
		{"sites": [[3, 3], [6, 2], [10, 2]]},
		{"sites": [[3, 2], null, [10, 2]]},
		{"resources": []}, {"resources": [{"kind": "seal", "cell": [1, 2]}]},
		{"resources": [{"kind": "spool", "cell": [3, 2]}]},
		{"resources": [{"kind": "spool", "cell": [1, INF]}]},
		{"effect_cells": [[12, 2]]},
	]:
		var bad: Dictionary = cable.duplicate(true)
		bad.merge(change, true)
		check(not schema.validate(bad, level).is_empty(), "Malformed cable is rejected: " + str(change))
	var rack := {
		"type": "assemble_rack", "sites": [[10, 2]],
		"resources": [
			{"kind": "chassis", "cell": [1, 2]}, {"kind": "psu", "cell": [3, 2]},
			{"kind": "dimm", "cell": [5, 2]},
		],
	}
	check(schema.validate(rack, level).is_empty(), "Rack declares three unique components.")
	rack["resources"][2]["kind"] = "psu"
	check(not schema.validate(rack, level).is_empty(), "Duplicate components cannot substitute for memory.")
	for kind: String in ["extinguish_fire", "restore_cooling", "contain_leak", "restore_power"]:
		var resource: String = {"extinguish_fire": "extinguisher", "restore_cooling": "filter", "contain_leak": "seal", "restore_power": "fuse"}[kind]
		var task := {"type": kind, "sites": [[3, 2]], "resources": [{"kind": resource, "cell": [1, 2]}]}
		if kind in ["restore_cooling", "contain_leak"]:
			task["sites"].append([6, 2])
		if kind != "restore_power":
			var hazard: String = {"extinguish_fire": "fire", "restore_cooling": "heat_vent", "contain_leak": "electrified_liquid"}[kind]
			level["hazards"] = [{"kind": hazard, "cell": Vector2i(12, 2)}]
			task["effect_cells"] = [[12, 2]]
		check(schema.validate(task, level).is_empty(), "Valid service schema: " + kind)
		if kind != "restore_power":
			task["effect_cells"] = [[11, 2]]
			check(not schema.validate(task, level).is_empty(), "Effect requires an actual matching hazard.")
	finish()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)


func finish() -> void:
	print("WORK_SCHEMA_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
