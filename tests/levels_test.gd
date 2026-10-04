extends SceneTree

const LevelParser = preload("res://game/level_parser.gd")
const LevelValidator = preload("res://game/level_validator.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var parser := LevelParser.new()
	var validator := LevelValidator.new()
	var files: Array[String] = []
	for file_name: String in DirAccess.get_files_at("res://levels"):
		if file_name.ends_with(".level"):
			files.append("res://levels/" + file_name)
	check(not files.is_empty(), "At least one level file exists.")
	for path: String in files:
		var level := parser.parse(FileAccess.get_file_as_string(path), path)
		check(not level.is_empty(), "Level parses: " + parser.error_message)
		if level.is_empty():
			continue
		var errors := validator.validate(level)
		check(errors.is_empty(), "%s: %s" % [path, "; ".join(PackedStringArray(errors))])
	print("LEVELS_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
