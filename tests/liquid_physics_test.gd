# godot_test_args: --fixed-fps 60
extends SceneTree

const LEVEL := preload("res://game/level.tscn")
const Runner := preload("res://game/route_runner.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for hero: String in ["man", "woman"]:
		var level := LEVEL.instantiate()
		level.character = hero
		level.level_path = "res://tests/fixtures/liquid.level"
		root.add_child(level)
		check(level.error_message.is_empty(), "Production liquid fixture loads: " + level.error_message)
		if not level.error_message.is_empty():
			level.queue_free()
			await process_frame
			continue
		check(level.entities["liquids"].size() == 3, "All pool tiles belong to the liquid progress group.")
		var runner := Runner.new([
			{"hold": ["move_right"], "until_x": 190, "max_seconds": 3},
			{"wait": 0.3},
			{"hold": ["repair"], "seconds": 2.15},
			{"hold": ["move_right"], "until_x": 360, "max_seconds": 4},
		])
		var protected := false
		var saw_death := false
		var ticks := 0
		while level.respawns == 0 and not runner.failed and ticks < 480:
			runner.apply(level, 1.0 / 60.0)
			if level.player.position.x >= 295 and not protected:
				level.health.damage()
				protected = true
			await physics_frame
			ticks += 1
			if level.health.segments == 0:
				saw_death = true
				check(level.player.dead and not level.completed, "Real liquid contact enters death instead of completing the level.")
		check(not runner.failed and protected and saw_death and level.respawns == 1, hero + ": protected contact reaches one checkpoint recovery.")
		check(level.checkpoints.index == 0 and absf(level.player.position.x - 144) < 2, "Recovery uses the safe authored checkpoint.")
		check(not level.tasks.is_done("r1") and not level.entities["racks"][0].done, "Work completed after the checkpoint is undone.")
		check(level.health.segments == 5, "Recovery restores full health.")
		for liquid in level.entities["liquids"]:
			liquid.restore_state({"active": false})
			liquid.reset_motion()
		var dry_route := Runner.new([{"hold": ["move_right"], "until_x": 480, "max_seconds": 4}])
		ticks = 0
		while not dry_route.done() and not dry_route.failed and ticks < 300:
			dry_route.apply(level, 1.0 / 60.0)
			await physics_frame
			ticks += 1
		check(dry_route.done() and not dry_route.failed, "Draining permits a route across the same floor.")
		check(level.player.is_on_floor() and absf(level.player.position.y - 416) < 1, "Draining never removes the solid floor.")
		check(level.respawns == 1 and level.health.segments == 5, "Motion reset did not reactivate drained liquid.")
		level.queue_free()
		await process_frame
		var jump_level := LEVEL.instantiate()
		jump_level.character = hero
		jump_level.level_path = "res://tests/fixtures/liquid.level"
		root.add_child(jump_level)
		var jump_route := Runner.new([
			{"hold": ["move_right"], "until_x": 292, "max_seconds": 4},
			{"hold": ["move_right", "jump"], "seconds": 0.45},
			{"hold": ["move_right"], "until_x": 480, "max_seconds": 4},
		])
		ticks = 0
		while not jump_route.done() and not jump_route.failed and ticks < 400:
			jump_route.apply(jump_level, 1.0 / 60.0)
			await physics_frame
			ticks += 1
		check(jump_route.done() and not jump_route.failed and jump_level.health.hits_taken == 0 and jump_level.respawns == 0, hero + ": a real jump clears the active pool without damage.")
		jump_level.queue_free()
		await process_frame
	print("LIQUID_PHYSICS_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
