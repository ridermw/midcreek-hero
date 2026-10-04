# godot_test_args: --fixed-fps 60
extends SceneTree

const LEVEL := preload("res://game/level.tscn")
const Runner := preload("res://game/route_runner.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var steps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://levels/routes/03-cable-jungle.route.json"))
	var prefix: Array = []
	var found_ladder := false
	for step: Dictionary in steps:
		prefix.append(step)
		if step.get("until_y") == 300:
			found_ladder = true
			break
	check(found_ladder, "The authored route reaches the first ladder.")
	if not found_ladder:
		quit(1)
		return
	prefix.append({"hold": ["move_down"], "seconds": 0.6})
	prefix.append({"hold": ["move_up"], "until_y": 300, "max_seconds": 3})
	for hero: String in ["man", "woman"]:
		var level := LEVEL.instantiate()
		level.character = hero
		level.level_path = "res://levels/03-cable-jungle.level"
		root.add_child(level)
		check(level.error_message.is_empty(), "Level loads for " + hero)
		var runner := Runner.new(prefix)
		var ticks := 0
		var directions := {}
		var synchronized := true
		while not runner.done() and not runner.failed and ticks < 1500:
			runner.apply(level, 1.0 / 60.0)
			await physics_frame
			ticks += 1
			var velocity: Vector2 = level.player.velocity
			if level.player.motor.climbing and velocity.y != 0.0:
				directions[signf(velocity.y)] = true
				var sprite: AnimatedSprite2D = level.player.sprite
				if sprite.animation != &"climb" or not sprite.is_playing() or sprite.get_playing_speed() == 0.0:
					synchronized = false
				else:
					var frames: SpriteFrames = sprite.sprite_frames
					var cycles_per_second := sprite.get_playing_speed() * frames.get_animation_speed(&"climb") / frames.get_frame_count(&"climb")
					synchronized = synchronized and is_equal_approx(-velocity.y / cycles_per_second, 32.0)
		check(runner.done() and not runner.failed, hero + ": the ascent, descent, and return finish. " + runner.error_message)
		check(directions.has(-1.0) and directions.has(1.0), hero + ": real physics exercises both climb directions.")
		check(synchronized, hero + ": climb playback matches vertical movement.")
		check(level.health.hits_taken == 0 and level.respawns == 0, hero + ": the climb segment remains safe.")
		level.queue_free()
		await process_frame
	print("CLIMB_ROUTE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
