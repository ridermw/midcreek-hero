# godot_test_args: --fixed-fps 60
extends SceneTree

const LEVEL = preload("res://game/level.tscn")
const Runner = preload("res://game/route_runner.gd")
# Strict known gaps: a listed replay must still take hits and pass every other check.
# Key "<level>-<checkpoint index>": reason and owning change. Empty when none remain.
const KNOWN_GAPS := {}
var checks := 0
var failures := 0
var saved: Array[Dictionary] = []


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var budgets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/route_budgets.json"))
	var selected := selected_prefixes(OS.get_environment("EXPANSION_ONLY"))
	var played := {}
	for filename: String in DirAccess.get_files_at("res://levels/routes"):
		if not filename.ends_with(".route.json") or not selected.has(filename.substr(0, 2)):
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
			check(saved.size() == level.entities["checkpoints"].size(), filename + ": route activates every checkpoint.")
			level.queue_free()
			await process_frame
			for checkpoint: Dictionary in saved:
				await idle_after_restore(filename, hero, checkpoint)
				var retry := restore(filename, hero, checkpoint)
				var gap: String = KNOWN_GAPS.get("%s-%d" % [filename.substr(0, 2), checkpoint["index"]], "")
				await play(retry, Runner.new(steps.slice(checkpoint["route"])), float(budgets[filename.substr(0, 2)]), false, gap)
				retry.queue_free()
				await process_frame
			played[filename.substr(0, 2) + "-" + hero] = true
	for prefix: String in selected:
		for hero: String in ["man", "woman"]:
			check(played.has(prefix + "-" + hero), "Level %s plays its full route and every checkpoint for %s." % [prefix, hero])
	print("EXPANSION_ROUTE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


# Empty selects levels 01 to 15; CI passes comma-separated groups such as "01,02,03".
func selected_prefixes(only: String) -> PackedStringArray:
	if not only.is_empty():
		return only.split(",", false)
	var all := PackedStringArray()
	for number: int in range(1, 16):
		all.append("%02d" % number)
	return all


# Decision 1A: a restored hero who holds still for 2 s is never hit.
func idle_after_restore(filename: String, hero: String, checkpoint: Dictionary) -> void:
	var level := restore(filename, hero, checkpoint)
	var runner := Runner.new([{"wait": 2.0}])
	for frame: int in range(120):
		runner.apply(level, 1.0 / 60.0)
		await physics_frame
	check(level.health.hits_taken == 0 and level.respawns == 1, "%s %s idles 2 s after checkpoint %d restore without hits (hits=%d)." % [filename, hero, checkpoint["index"], level.health.hits_taken])
	level.queue_free()
	await process_frame


func restore(filename: String, hero: String, checkpoint: Dictionary) -> Node:
	var level := make_level(filename, hero)
	level.checkpoints.index = checkpoint["index"]
	level.checkpoints.spawn_position = checkpoint["spawn"]
	level.checkpoints._timer_value = checkpoint["time"]
	level.checkpoints._completed.assign(checkpoint["done"])
	level.checkpoints.level_state = checkpoint["state"].duplicate(true)
	level._respawn()
	return level


func make_level(filename: String, hero: String) -> Node:
	var level := LEVEL.instantiate()
	level.character = hero
	level.level_path = "res://levels/" + filename.trim_suffix(".route.json") + ".level"
	root.add_child(level)
	check(level.error_message.is_empty(), filename + ": " + level.error_message)
	return level


func play(level: Node, runner: RefCounted, budget: float, record: bool, known_gap := "") -> void:
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
	check(level.respawns == respawns, "Route has no additional respawns.")
	if known_gap.is_empty():
		check(level.health.hits_taken == 0, "Route has zero hits.")
	else:
		print("KNOWN_GAP: %s hits=%d (%s)" % [level.character, level.health.hits_taken, known_gap])
		check(level.health.hits_taken > 0, "Known gap now passes; remove it from KNOWN_GAPS: " + known_gap)
	check(level.timer.elapsed < float(level.level["header"]["sla_seconds"]) and frames / 60.0 <= budget, "Replay meets SLA and the independent route budget.")
	if level.completed:
		print("EXPANSION_ROUTE %s %s checkpoint=%d seconds=%.2f hits=%d additional_respawns=%d" % [level.level_path, level.character, previous, frames / 60.0, level.health.hits_taken, level.respawns - respawns])


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
