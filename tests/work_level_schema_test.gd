extends SceneTree

const Parser = preload("res://game/level_parser.gd")
const Validator = preload("res://game/level_validator.gd")
const Tasks = preload("res://game/task_system.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var tasks := [
		{"id": "cable", "type": "run_cable", "required": true, "sites": [[4, 2], [7, 2], [10, 2]], "resources": [{"kind": "spool", "cell": [3, 2]}]},
		{"id": "power", "type": "restore_power", "required": true, "sites": [[20, 2]], "resources": [{"kind": "fuse", "cell": [18, 2]}]},
		{"id": "rack", "type": "assemble_rack", "required": true, "sites": [[30, 2]], "resources": [{"kind": "chassis", "cell": [25, 2]}, {"kind": "psu", "cell": [26, 2]}, {"kind": "dimm", "cell": [27, 2]}]},
	]
	var parser := Parser.new()
	var level := parser.parse(text(tasks), "work schema")
	check(not level.is_empty(), "Production parser accepts coordinate work tasks: " + parser.error_message)
	if not level.is_empty():
		check(Validator.new().validate(level).is_empty(), "Validator accepts reachable work sites and resources.")
	var registry := Tasks.new()
	for task: Dictionary in tasks:
		check(registry.add_task(task["id"], task["type"], true).is_empty(), "Registry accepts " + task["type"])
	var overlap: Array = tasks.duplicate(true)
	overlap[1]["sites"] = [[4, 2]]
	check(parser.parse(text(overlap), "overlap").is_empty(), "Two tasks cannot own the same interaction cell.")
	overlap = tasks.duplicate(true)
	overlap[1]["resources"][0]["cell"] = [7, 2]
	check(parser.parse(text(overlap), "resource overlap").is_empty(), "Resources cannot overlap another task's site.")
	var floating: Array = tasks.duplicate(true)
	floating[1]["sites"] = [[20, 0]]
	level = parser.parse(text(floating), "floating")
	check(not level.is_empty(), "Syntactically valid floating site reaches the terrain validator.")
	if not level.is_empty():
		check(not Validator.new().validate(level).is_empty(), "Terrain validator rejects unsupported work sites.")
	var cooling := {"id": "cool", "type": "restore_cooling", "required": true, "sites": [[4, 2], [7, 2]], "resources": [{"kind": "filter", "cell": [3, 2]}], "effect_cells": [[12, 2]]}
	var service := [cooling, tasks[1], tasks[2]]
	level = parser.parse(text(service, "v"), "cooling")
	check(not level.is_empty(), "Cooling binds an actual heat source: " + parser.error_message)
	var exposed: Dictionary = tasks[1].duplicate(true)
	exposed["sites"] = [[12, 2]]
	for definitions: Array in [[cooling, exposed, tasks[2]], [exposed, cooling, tasks[2]]]:
		check(parser.parse(text(definitions, "v"), "hazard site overlap").is_empty(), "A bound effect cannot occupy another task's site in either definition order.")
	var second: Dictionary = cooling.duplicate(true)
	second["id"] = "cool2"
	second["sites"] = [[15, 2], [17, 2]]
	second["resources"][0]["cell"] = [16, 2]
	check(parser.parse(text([cooling, second, tasks[2]], "v"), "double effect").is_empty(), "Two tasks cannot control the same hazard.")
	var fire := {"id": "fire", "type": "extinguish_fire", "required": true, "sites": [[7, 2]], "resources": [{"kind": "extinguisher", "cell": [3, 2]}], "effect_cells": [[12, 2]]}
	check(not parser.parse(text([fire, tasks[1], tasks[2]], "f"), "fire").is_empty(), "Fire work has a distinct fire hazard.")
	check(parser.parse(text([fire, tasks[1], tasks[2]], "v"), "wrong hazard").is_empty(), "Fire work cannot bind heat vents.")
	print("WORK_LEVEL_SCHEMA_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func text(tasks: Array, hazard: String = ".") -> String:
	var header := {"name": "Work schema", "music": "cold-aisle", "background": "cold-aisle", "par_seconds": 100, "sla_seconds": 200, "tasks": tasks}
	var row := "P.C.........%s.........C............C...E" % hazard
	return JSON.stringify(header) + "\n---\n" + ".".repeat(row.length()) + "\n" + ".".repeat(row.length()) + "\n" + row + "\n" + "#".repeat(row.length())


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
