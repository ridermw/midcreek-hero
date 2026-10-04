extends SceneTree

const LevelParser = preload("res://game/level_parser.gd")
const LevelValidator = preload("res://game/level_validator.gd")
const VALID_HEADER := {
	"name": "Fixture",
	"sla_seconds": 120,
	"par_seconds": 60,
	"music": "level1",
	"background": "cold-aisle",
	"tasks": [
		{"id": "r1", "type": "repair", "at": ["A"], "required": true},
		{"id": "f1", "type": "fetch", "at": ["B"], "part_at": "D", "part": "psu", "required": true},
		{"id": "o1", "type": "reseat", "at": ["F"], "required": false},
	],
}
const VALID_GRID: Array[String] = [
	"............",
	"......==....",
	"P.A.D.C.BsFE",
	"############",
]

var checks: int = 0
var failures: int = 0
var parser := LevelParser.new()


func _initialize() -> void:
	run.call_deferred()


func level_text(header: Dictionary, grid: Array[String]) -> String:
	return JSON.stringify(header, "  ") + "\n---\n" + "\n".join(PackedStringArray(grid)) + "\n"


func grid_with(row_index: int, row: String) -> Array[String]:
	var grid: Array[String] = VALID_GRID.duplicate()
	grid[row_index] = row
	return grid


func header_with(key: String, value: Variant) -> Dictionary:
	var header: Dictionary = VALID_HEADER.duplicate(true)
	header[key] = value
	return header


func task_header(task: Dictionary) -> Dictionary:
	var header: Dictionary = VALID_HEADER.duplicate(true)
	header["tasks"][0] = task
	return header


func expect_error(text: String, needle: String) -> void:
	var level := parser.parse(text, "fixture.level")
	check(
		level.is_empty() and parser.error_message.contains(needle),
		"Expected error '%s', got '%s'." % [needle, parser.error_message],
	)


func run() -> void:
	var level := parser.parse(level_text(VALID_HEADER, VALID_GRID), "fixture.level")
	check(not level.is_empty() and parser.error_message.is_empty(), "Valid level parses.")
	check(level.get("width") == 12 and level.get("height") == 4, "Width and height match the grid.")
	check(
		level.get("player_start") == Vector2i(0, 2) and level.get("exit") == Vector2i(11, 2),
		"Start and exit cells are recorded.",
	)
	check(
		level["solids"].get(Vector2i(0, 3)) == "floor" and level["solids"].get(Vector2i(6, 1)) == "platform",
		"Solid kinds are recorded.",
	)
	check(
		level["checkpoints"].size() == 1 and level["checkpoints"][0] == Vector2i(6, 2),
		"Checkpoints are recorded.",
	)
	check(
		level["hazards"].size() == 1
		and level["hazards"][0]["kind"] == "cable_snag"
		and level["hazards"][0]["cell"] == Vector2i(9, 2),
		"Hazards are recorded.",
	)
	check(
		level["anchors"] == {"A": Vector2i(2, 2), "D": Vector2i(4, 2), "B": Vector2i(8, 2), "F": Vector2i(10, 2)},
		"Anchors are recorded.",
	)
	var header_lines := JSON.stringify(VALID_HEADER, "  ").split("\n").size()
	expect_error("\n".join(PackedStringArray(VALID_GRID)), "Missing '---'")
	expect_error("{not json\n---\n" + "\n".join(PackedStringArray(VALID_GRID)), "Invalid header JSON")
	expect_error(level_text(header_with("par_seconds", 200), VALID_GRID), "par_seconds must be")
	expect_error(level_text(header_with("music", 5), VALID_GRID), "Header key 'music'")
	expect_error(level_text(VALID_HEADER, grid_with(1, "...")), "Row width 3 differs from first row width 12.")
	expect_error(
		level_text(VALID_HEADER, grid_with(2, "P.A?D.C.BsFE")),
		"fixture.level:%d: Unknown legend character '?'. (column 4)" % (header_lines + 4),
	)
	expect_error(level_text(VALID_HEADER, grid_with(0, "P...........")), "Second 'P' marker.")
	expect_error(level_text(VALID_HEADER, grid_with(2, "P.A.D.C.BsF.")), "Missing exit 'E'.")
	expect_error(level_text(VALID_HEADER, grid_with(0, "CCC.........")), "More than 3 checkpoints.")
	expect_error(
		level_text(task_header({"id": "r1", "type": "repair", "at": ["Z"], "required": true}), VALID_GRID),
		"references missing anchor 'Z'",
	)
	expect_error(level_text(VALID_HEADER, grid_with(0, "G...........")), "Anchor 'G' is not used")
	expect_error(level_text(VALID_HEADER, grid_with(0, "A...........")), "Anchor 'A' appears more than once.")
	expect_error(
		level_text(task_header({"id": "r1", "type": "dance", "at": ["A"], "required": true}), VALID_GRID),
		"unknown type 'dance'",
	)
	var optional_header: Dictionary = VALID_HEADER.duplicate(true)
	for task: Dictionary in optional_header["tasks"]:
		task["required"] = false
	expect_error(level_text(optional_header, VALID_GRID), "At least one task must be required.")
	expect_error(
		level_text(task_header({"id": "b1", "type": "reboot", "at": ["A"], "required": true}), VALID_GRID),
		"Reboot task 'b1' needs 3 'at' anchors.",
	)
	expect_error(
		level_text(task_header({"id": "", "type": "repair", "at": ["A"], "required": true}), VALID_GRID),
		"Task id must not be empty.",
	)
	expect_error(
		level_text(task_header({"id": "f1", "type": "repair", "at": ["A"], "required": true}), VALID_GRID),
		"Duplicate task id: f1",
	)
	var duplicate_optional: Dictionary = VALID_HEADER.duplicate(true)
	duplicate_optional["tasks"][2]["id"] = "r1"
	expect_error(level_text(duplicate_optional, VALID_GRID), "Duplicate task id: r1")
	for invalid_label: Variant in [null, 42, true, [], {}]:
		var task: Dictionary = VALID_HEADER["tasks"][0].duplicate(true)
		task["label"] = invalid_label
		expect_error(level_text(task_header(task), VALID_GRID), "Task 'r1' label must be a string.")
	for label: String in ["", "Repair the first rack"]:
		var task: Dictionary = VALID_HEADER["tasks"][0].duplicate(true)
		task["label"] = label
		var labeled_level := parser.parse(level_text(task_header(task), VALID_GRID), "fixture.level")
		check(not labeled_level.is_empty(), "String task labels remain valid.")
		if not labeled_level.is_empty():
			check(labeled_level["header"]["tasks"][0]["label"] == label, "Task label is preserved.")
	var spec := FileAccess.get_file_as_string(
		"res://docs/superpowers/specs/2026-10-03-datacenter-side-scroller-design.md",
	)
	var example := spec.get_slice("### Level file format\n", 1).get_slice("```text\n", 1).get_slice("```", 0)
	var example_level := parser.parse(example, "spec example")
	check(not example_level.is_empty(), "Spec level example parses: " + parser.error_message)
	if not example_level.is_empty():
		var example_errors := LevelValidator.new().validate(example_level)
		check(example_errors.is_empty(), "Spec level example is playable: " + str(example_errors))
	expect_error(level_text(header_with("prompts", [{"x": 99, "text": "Hi"}]), VALID_GRID), "Prompt column 99 is outside the grid.")
	expect_error(level_text(header_with("prompts", [{"x": 1}]), VALID_GRID), "Each prompt needs an integer x and a text string.")
	check(not parser.parse(level_text(header_with("prompts", [{"x": 1, "text": "Hi"}]), VALID_GRID), "p.level").is_empty(), "Valid prompts parse.")
	expect_error(
		level_text(task_header({"id": "f9", "type": "fetch", "at": ["A"], "part_at": "Z", "part": "psu", "required": true}), VALID_GRID),
		"references missing anchor 'Z'",
	)
	var no_part: Dictionary = VALID_HEADER.duplicate(true)
	no_part["tasks"][1].erase("part")
	expect_error(level_text(no_part, VALID_GRID), "Fetch task 'f1' part must be psu or dimm.")
	var gpu_header: Dictionary = VALID_HEADER.duplicate(true)
	gpu_header["tasks"][1]["part"] = "gpu"
	expect_error(level_text(gpu_header, VALID_GRID), "Fetch task 'f1' part must be psu or dimm.")
	expect_error(level_text(header_with("darkness", "false"), VALID_GRID), "Header key 'darkness' must be true or false.")
	check(not parser.parse(level_text(header_with("darkness", false), VALID_GRID), "d.level").is_empty(), "darkness false parses.")
	print("LEVEL_PARSER_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
