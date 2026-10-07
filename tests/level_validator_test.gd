extends SceneTree

const LevelParser = preload("res://game/level_parser.gd")
const LevelValidator = preload("res://game/level_validator.gd")
const Lift = preload("res://game/entities/lift.gd")
const ONE_TASK_HEADER := {
	"name": "Reach",
	"sla_seconds": 120,
	"par_seconds": 60,
	"music": "level1",
	"background": "cold-aisle",
	"tasks": [{"id": "r1", "type": "repair", "at": ["A"], "required": true}],
}
const LIFT_SITES := [
	{"slug": "04-power-room", "cells": [Vector2i(42, 12), Vector2i(94, 12), Vector2i(157, 12), Vector2i(282, 12)]},
	{"slug": "05-outage-night", "cells": [Vector2i(59, 12), Vector2i(220, 12)]},
]

var checks: int = 0
var failures: int = 0
var parser := LevelParser.new()
var validator := LevelValidator.new()


func _initialize() -> void:
	run.call_deferred()


func fixture_text() -> String:
	return FileAccess.get_file_as_string("res://tests/fixtures/controller.level")


func parse_text(text: String) -> Dictionary:
	var level := parser.parse(text, "fixture.level")
	if level.is_empty():
		push_error(parser.error_message)
	return level


func parse_level(slug: String) -> Dictionary:
	var level := parser.parse(FileAccess.get_file_as_string("res://levels/%s.level" % slug), slug)
	if level.is_empty():
		push_error(parser.error_message)
	return level


func errors_of(text: String) -> String:
	return "\n".join(PackedStringArray(validator.validate(parse_text(text))))


func lift_constants() -> Dictionary:
	var lift := Lift.new()
	var constants: Dictionary = lift.get_script().get_script_constant_map()
	lift.free()
	return constants


func reach_level(platform_row: int, platform_x: int) -> Dictionary:
	var rows: Array[String] = []
	for y: int in range(4):
		var row := "............"
		if y == platform_row:
			row = row.substr(0, platform_x) + "=" + row.substr(platform_x + 1)
		rows.append(row)
	rows.append("PEA.........")
	rows.append("####........")
	var text := JSON.stringify(ONE_TASK_HEADER) + "\n---\n" + "\n".join(PackedStringArray(rows))
	return parse_text(text)


func run() -> void:
	var lift_rise := Vector2i(0, int(lift_constants().get("RISE_TILES", 0)))
	check(lift_rise == Vector2i(0, 5), "The validator uses the lift's 5 tile runtime rise.")
	var text := fixture_text()
	check(validator.validate(parse_text(text)).is_empty(), "The controller fixture is valid.")

	var lift_level := {
		"width": 5, "height": 8, "player_start": Vector2i(2, 6),
		"solids": {Vector2i(2, 7): "#"}, "ladders": [], "lifts": [Vector2i(2, 6)],
	}
	check(validator.reachable_cells(lift_level).has(Vector2i(2, 1)), "An unobstructed lift reaches its top 5 tiles up.")
	for row: int in range(1, 7):
		var obstructed: Dictionary = lift_level.duplicate(true)
		obstructed["solids"][Vector2i(2, row)] = "#"
		check(not validator.reachable_cells(obstructed).has(Vector2i(2, 1)), "A solid at shaft row %d prevents lift top access." % row)
	for column: int in [1, 3]:
		for row: int in range(2, 7):
			var obstructed: Dictionary = lift_level.duplicate(true)
			obstructed["solids"][Vector2i(column, row)] = "#"
			check(not validator.reachable_cells(obstructed).has(Vector2i(2, 1)), "A solid at side column %d, row %d blocks the 96 px deck sweep." % [column, row])
	for column: int in [1, 3]:
		var side_top: Dictionary = lift_level.duplicate(true)
		side_top["solids"][Vector2i(column, 1)] = "#"
		check(validator.reachable_cells(side_top).has(Vector2i(2, 1)), "Side solids at the rider-only top row do not block the deck sweep.")
	var alternate: Dictionary = lift_level.duplicate(true)
	alternate["player_start"] = Vector2i(0, 1)
	alternate["solids"][Vector2i(0, 2)] = "#"
	alternate["solids"][Vector2i(1, 2)] = "#"
	alternate["solids"][Vector2i(2, 2)] = "#"
	check(validator.reachable_cells(alternate).has(Vector2i(2, 1)), "Ordinary terrain at a lift top remains reachable from an adjacent platform.")

	var unused_lift := parse_text(FileAccess.get_file_as_string("res://tests/fixtures/power_room.level"))
	check(validator.validate(unused_lift).is_empty(), "The Power Room fixture has a clear 5 tile lift shaft.")
	for column: int in [19, 20, 21]:
		var rows: Array = range(1, 7) if column == 20 else range(2, 7)
		for row: int in rows:
			var obstructed: Dictionary = unused_lift.duplicate(true)
			obstructed["solids"][Vector2i(column, row)] = "#"
			check(not validator.validate(obstructed).is_empty(), "A solid at column %d, row %d blocks the lift sweep." % [column, row])
	for edge: int in [0, 29]:
		var outside_width: Dictionary = unused_lift.duplicate(true)
		outside_width["lifts"] = [Vector2i(edge, 6)]
		check(not validator.validate(outside_width).is_empty(), "A lift at column %d cannot extend its 96 px deck outside the level." % edge)
	var outside_sweep: Dictionary = unused_lift.duplicate(true)
	outside_sweep["solids"][Vector2i(18, 3)] = "#"
	check(validator.validate(outside_sweep).is_empty(), "Solids outside the lift footprint do not block its sweep.")
	for column: int in [19, 21]:
		var above_deck: Dictionary = unused_lift.duplicate(true)
		above_deck["solids"][Vector2i(column, 1)] = "#"
		check(validator.validate(above_deck).is_empty(), "A neighboring ledge above the deck sweep remains valid.")
	var above_level := parse_text(text)
	above_level["lifts"].append(Vector2i(1, 2))
	check(not validator.validate(above_level).is_empty(), "An unused lift cannot travel above the level.")

	for site_group: Dictionary in LIFT_SITES:
		var level := parse_level(site_group["slug"])
		for lift: Vector2i in site_group["cells"]:
			var top := lift - lift_rise
			check(validator.reachable_cells(level).has(top), "%s lift at column %d reaches its upper story." % [site_group["slug"], lift.x])
			var without := level.duplicate(true)
			without["lifts"].erase(lift)
			check(not validator.reachable_cells(without).has(top), "%s lift at column %d cannot be bypassed by validator reachability." % [site_group["slug"], lift.x])
			for checkpoint: Vector2i in level["checkpoints"]:
				var in_x := checkpoint.x >= lift.x - 1 and checkpoint.x <= lift.x + 1
				var in_y := checkpoint.y >= top.y and checkpoint.y <= lift.y
				check(not (in_x and in_y), "%s checkpoint at %s is not in the lift shaft." % [site_group["slug"], checkpoint])

	var two_checkpoints := text.replace("..C..F..E", ".....F..E")
	check(
		errors_of(two_checkpoints).contains("Level needs exactly 3 checkpoints, found 2."),
		"Shipped levels need 3 checkpoints.",
	)
	var two_tasks := text.replace(
		',\n    {"id": "o1", "type": "repair", "at": ["F"], "required": false}', ""
	).replace("..F..E", ".....E")
	check(errors_of(two_tasks).contains("Level needs 3 to 6 tasks, found 2."), "Shipped levels need 3 tasks.")
	var floating_anchor := text.replace(
		"---\n..............................\n",
		"---\n...A..........................\n",
	).replace("P..A..C", "P.....C")
	check(
		errors_of(floating_anchor).contains("anchor A at column 4, row 1 is not standable."),
		"An anchor in the air is not standable.",
	)
	check(validator.reachable_cells(reach_level(2, 5)).has(Vector2i(5, 1)), "3 up and 2 across is reachable.")
	check(not validator.reachable_cells(reach_level(2, 7)).has(Vector2i(7, 1)), "3 up and 4 across is not reachable.")
	check(validator.reachable_cells(reach_level(3, 6)).has(Vector2i(6, 2)), "2 up and 3 across is reachable.")
	check(not validator.reachable_cells(reach_level(3, 7)).has(Vector2i(7, 2)), "2 up and 4 across is not reachable.")
	print("LEVEL_VALIDATOR_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
