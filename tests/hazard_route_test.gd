# godot_test_args: --fixed-fps 60
extends SceneTree

const LEVEL = preload("res://game/level.tscn")
const RouteRunner = preload("res://game/route_runner.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var valid := RouteRunner.new([{"hold": ["move_right"], "until_hazard": 304, "gap": 62, "max_seconds": 8}])
	check(valid.error_message.is_empty(), "until_hazard is a valid stop condition: " + valid.error_message)
	for bad: Dictionary in [
		{"hold": ["move_right"], "until_hazard": 304, "max_seconds": 8},
		{"hold": ["move_right"], "until_hazard": 304, "gap": 62},
		{"hold": ["move_left"], "until_hazard": 304, "gap": 62, "max_seconds": 8},
		{"hold": ["move_right"], "until_hazard": "x", "gap": 62, "max_seconds": 8},
		{"hold": ["move_right"], "until_hazard": 304, "gap": 62, "max_seconds": 8, "until_x": 3},
	]:
		check(not RouteRunner.new([bad]).error_message.is_empty(), "Malformed hazard step is rejected: %s" % bad)
	var text := FileAccess.get_file_as_string("res://tests/fixtures/controller.level")
	for kind: String in ["s", "m"]:
		var path := "user://hazard-route-%s.level" % kind
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text.replace("..s..", "..%s.." % kind))
		file.close()
		var waited := false
		for phase: float in [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]:
			for hero: String in ["man", "woman"]:
				var level := LEVEL.instantiate()
				level.character = hero
				level.level_path = path
				root.add_child(level)
				var pile: Node2D = level.entities["hazards"][0]
				var origin: float = pile.patrol.origin
				pile.advance(phase)
				if kind == "m" and phase == 0.0:
					# The pile moves away from a close standing start, so a jump now would land on it.
					level.player.respawn(Vector2(origin - 70.0, level.player.position.y))
					check(not RouteRunner.jump_clear(level, pile, 62.0), "A close jump after a pile moving away is predicted unclear.")
				var runner := RouteRunner.new([
					{"hold": ["move_right"], "until_hazard": origin, "gap": 62, "max_seconds": 8},
					{"hold": ["move_right", "jump"], "seconds": 0.45},
					{"hold": ["move_right"], "until_x": origin + 200.0, "max_seconds": 4},
				])
				for frame: int in range(900):
					runner.apply(level, 1.0 / 60.0)
					waited = waited or (runner.index == 0 and level.player.input_override.get("direction", 0.0) <= 0.0)
					await physics_frame
					if runner.done() or runner.failed or level.health.hits_taken > 0:
						break
				check(runner.done() and level.health.hits_taken == 0, "%s %s: the route clears the pile from patrol phase %.1f s (hits=%d, %s)." % [kind, hero, phase, level.health.hits_taken, runner.error_message])
				level.queue_free()
				await process_frame
		if kind == "m":
			check(waited, "The route waits or backs away when a jump over the moving pile is not yet clear.")
	var pair := "user://hazard-route-pair.level"
	var pair_file := FileAccess.open(pair, FileAccess.WRITE)
	pair_file.store_string(text.replace("C..B", "C.sB"))
	pair_file.close()
	for phase: float in [0.0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.2]:
		for hero: String in ["man", "woman"]:
			var level := LEVEL.instantiate()
			level.character = hero
			level.level_path = pair
			root.add_child(level)
			var piles: Array = level.entities["hazards"]
			for pile in piles:
				pile.advance(phase * (1.0 + piles.find(pile)))
			var runner := RouteRunner.new([
				{"hold": ["move_right"], "until_hazard": piles[0].patrol.origin, "gap": 62, "max_seconds": 12},
				{"hold": ["move_right", "jump"], "seconds": 0.45},
				{"hold": ["move_right"], "until_hazard": piles[1].patrol.origin, "gap": 62, "max_seconds": 12},
				{"hold": ["move_right", "jump"], "seconds": 0.45},
				{"hold": ["move_right"], "until_x": piles[1].patrol.origin + 160.0, "max_seconds": 4},
			])
			for frame: int in range(1800):
				runner.apply(level, 1.0 / 60.0)
				await physics_frame
				if runner.done() or runner.failed or level.health.hits_taken > 0:
					break
			check(runner.done() and level.health.hits_taken == 0, "%s: two piles 8 tiles apart clear from phase %.1f s (hits=%d, %s)." % [hero, phase, level.health.hits_taken, runner.error_message])
			level.queue_free()
			await process_frame
	print("HAZARD_ROUTE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
