# godot_test_args: --fixed-fps 60
extends SceneTree

const RouteRunner = preload("res://game/route_runner.gd")
const LEVEL_SCENE := preload("res://game/level.tscn")
const ROUTES := "res://levels/routes/"
const DT := 1.0 / 60.0

var checks: int = 0
var failures: int = 0
var trace: bool = OS.get_environment("ROUTE_TRACE") == "1"


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var files: Array[String] = []
	for file_name: String in DirAccess.get_files_at(ROUTES):
		var only := OS.get_environment("ROUTE_ONLY")
		if file_name.ends_with(".route.json") and (only.is_empty() or file_name.begins_with(only)):
			files.append(file_name)
	check(not files.is_empty(), "At least one route exists.")
	for file_name: String in files:
		await play(file_name)
	print("ROUTE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func play(file_name: String) -> void:
	var level_path := "res://levels/" + file_name.trim_suffix(".route.json") + ".level"
	var json := JSON.new()
	check(json.parse(FileAccess.get_file_as_string(ROUTES + file_name)) == OK, file_name + " parses.")
	var runner := RouteRunner.new(json.data)
	check(runner.error_message.is_empty(), file_name + ": " + runner.error_message)
	var level := LEVEL_SCENE.instantiate()
	level.level_path = level_path
	root.add_child(level)
	check(level.error_message.is_empty(), file_name + ": " + level.error_message)
	if file_name == "01-cold-aisle.route.json":
		var prompts: Array = level.level["header"]["prompts"]
		for i: int in range(3):
			var model := preload("res://game/control_prompt.gd").render(prompts[i], "gamepad")
			check(not model["graphic"].is_empty() and model["graphic"]["shape"] == "button", "Onboarding resolves selected gamepad controls.")
	var results: Array[Dictionary] = []
	level.finished.connect(func(result: Dictionary) -> void: results.append(result))
	var sla := float(level.level["header"]["sla_seconds"])
	var last_hits := 0
	var last_respawns := 0
	var frames := 0
	while results.is_empty() and not runner.failed and frames < int(sla * 60.0) + 600:
		var step_index := runner.index
		runner.apply(level, DT)
		await physics_frame
		frames += 1
		if trace and (runner.index != step_index or level.health.hits_taken != last_hits or level.respawns != last_respawns):
			print("TRACE f=%d step=%d pos=%s hits=%d respawns=%d tasks=%s" % [
				frames, runner.index, level.player.position.round(), level.health.hits_taken,
				level.respawns, level.tasks.completed_ids()
			])
			last_hits = level.health.hits_taken
			last_respawns = level.respawns
		if runner.done() and frames % 30 == 0 and trace:
			print("TRACE idle pos=%s" % level.player.position.round())
	check(not runner.failed, file_name + ": " + runner.error_message)
	check(results.size() == 1, "%s finishes (stopped at step %d, x=%.0f)." % [file_name, runner.index + 1, level.player.position.x])
	if results.size() == 1:
		var result := results[0]
		check(result["respawns"] == 0, "%s finishes without a respawn." % file_name)
		check(result["elapsed"] < sla, "%s finishes inside the SLA." % file_name)
		var header: Dictionary = level.level["header"]
		var par := float(header["par_seconds"])
		var expected_par := ceilf(float(result["elapsed"]) * 1.25 / 5.0) * 5.0
		var factor := 1.35 if file_name.begins_with("05-") else 1.6
		var expected_sla := ceilf(expected_par * factor / 5.0) * 5.0
		check(par == expected_par, "%s par %.0f follows the rule (expected %.0f)." % [file_name, par, expected_par])
		check(sla == expected_sla, "%s SLA %.0f follows the rule (expected %.0f)." % [file_name, sla, expected_sla])
		check(par >= 120.0 and par <= 240.0, "%s par %.0f s is 2 to 4 minutes." % [file_name, par])
		check(result["hits"] == 0, "%s finishes without damage." % file_name)
		print("ROUTE %s elapsed=%.2f hits=%d stars=%d optional=%d/%d" % [
			file_name, result["elapsed"], result["hits"], result["stars"],
			result["optional_done"], result["optional_total"]
		])
	level.queue_free()
	await process_frame


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
