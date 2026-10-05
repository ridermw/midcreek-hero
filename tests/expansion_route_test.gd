# godot_test_args: --fixed-fps 60
extends SceneTree

const LEVEL = preload("res://game/level.tscn")
const Runner = preload("res://game/route_runner.gd")
var checks := 0
var failures := 0
var saved: Array[Dictionary] = []


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var budgets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/route_budgets.json"))
	for filename: String in DirAccess.get_files_at("res://levels/routes"):
		if not filename.ends_with(".route.json") or int(filename.substr(0, 2)) < 6:
			continue
		var only := OS.get_environment("EXPANSION_ONLY")
		if not only.is_empty() and not filename.begins_with(only):
			continue
		var steps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/routes/" + filename))
		for hero: String in ["man", "woman"]:
			saved.clear()
			var level := make_level(filename, hero)
			if not level.error_message.is_empty():
				level.queue_free()
				await process_frame
				continue
			await play(level, Runner.new(steps), float(budgets[filename.substr(0, 2)]), true)
			check(saved.size() == 3, filename + ": route activates all three checkpoints.")
			level.queue_free()
			await process_frame
			for checkpoint: Dictionary in saved:
				var retry := make_level(filename, hero)
				retry.checkpoints.index = checkpoint["index"]
				retry.checkpoints.spawn_position = checkpoint["spawn"]
				retry.checkpoints._timer_value = checkpoint["time"]
				retry.checkpoints._completed.assign(checkpoint["done"])
				retry.checkpoints.level_state = checkpoint["state"].duplicate(true)
				retry._respawn()
				await play(retry, Runner.new(steps.slice(checkpoint["route"])), float(budgets[filename.substr(0, 2)]), false)
				retry.queue_free()
				await process_frame
	print("EXPANSION_ROUTE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func make_level(filename: String, hero: String) -> Node:
	var level := LEVEL.instantiate()
	level.character = hero
	level.level_path = "res://levels/" + filename.trim_suffix(".route.json") + ".level"
	root.add_child(level)
	check(level.error_message.is_empty(), filename + ": " + level.error_message)
	return level


func play(level: Node, runner: RefCounted, budget: float, record: bool) -> void:
	var respawns: int = level.respawns
	var previous: int = level.checkpoints.index
	var frames := 0
	while not level.completed and not runner.failed and frames < int(budget * 60):
		runner.apply(level, 1.0 / 60.0)
		await physics_frame
		frames += 1
		if record and level.checkpoints.index != previous:
			previous = level.checkpoints.index
			saved.append({
				"index": previous, "spawn": level.checkpoints.spawn_position,
				"time": level.checkpoints._timer_value, "done": level.checkpoints._completed.duplicate(),
				"state": level.checkpoints.level_state.duplicate(true), "route": runner.index,
			})
		if level.respawns != respawns:
			break
	check(not runner.failed, level.character + ": " + runner.error_message)
	check(level.completed, "%s checkpoint %d completes (step %d, position %s)." % [level.character, previous, runner.index, level.player.position])
	check(level.health.hits_taken == 0 and level.respawns == respawns, "Route has zero hits and no additional respawns.")
	check(level.timer.elapsed < float(level.level["header"]["sla_seconds"]) and frames / 60.0 <= budget, "Replay meets SLA and the independent route budget.")
	if level.completed:
		print("EXPANSION_ROUTE %s %s checkpoint=%d seconds=%.2f hits=%d additional_respawns=%d" % [level.level_path, level.character, previous, frames / 60.0, level.health.hits_taken, level.respawns - respawns])


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
