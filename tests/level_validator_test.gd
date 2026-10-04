extends SceneTree

const LevelParser = preload("res://game/level_parser.gd")
const LevelValidator = preload("res://game/level_validator.gd")
const ONE_TASK_HEADER := {
	"name": "Reach",
	"sla_seconds": 120,
	"par_seconds": 60,
	"music": "level1",
	"background": "cold-aisle",
	"tasks": [{"id": "r1", "type": "repair", "at": ["A"], "required": true}],
}

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


func errors_of(text: String) -> String:
	return "\n".join(PackedStringArray(validator.validate(parse_text(text))))


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
	var text := fixture_text()
	check(validator.validate(parse_text(text)).is_empty(), "The controller fixture is valid.")
	var unsupported_terrain := {"l": "lift"}
	for symbol: String in unsupported_terrain:
		var terrain_text := text.replace("---\n.", "---\n" + symbol)
		check(
			errors_of(terrain_text).contains("Terrain '%s' is not built yet." % unsupported_terrain[symbol]),
			"Unsupported terrain '%s' is rejected before level construction." % symbol,
		)
	var two_checkpoints := text.replace("..C..F..E", ".....F..E")
	check(
		errors_of(two_checkpoints).contains("Level needs exactly 3 checkpoints, found 2."),
		"Shipped levels need 3 checkpoints.",
	)
	var two_tasks := text.replace(
		',\n    {"id": "o1", "type": "repair", "at": ["F"], "required": false}', ""
	).replace("..F..E", ".....E")
	check(errors_of(two_tasks).contains("Level needs 3 to 6 tasks, found 2."), "Shipped levels need 3 tasks.")
	var high_exit := text.replace(
		"---\n..............................\n..............................\n",
		"---\n..........................E...\n......................#####...\n"
		+ "..............................\n..............................\n",
	).replace("..F..E\n", "..F...\n")
	check(
		errors_of(high_exit).contains("exit at column 27, row 1 is not reachable."),
		"An exit 4 tiles up is not reachable.",
	)
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
