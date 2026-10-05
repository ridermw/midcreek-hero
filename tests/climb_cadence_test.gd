extends SceneTree

const PLAYER := preload("res://game/player.tscn")
const Animations := preload("res://game/animation_library.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var library := Animations.new()
	check(library.load_manifest(), "Production animation assets load.")
	if library.variants.is_empty():
		quit(1)
		return
	for hero: String in ["man", "woman"]:
		var player = PLAYER.instantiate()
		player.character = hero
		root.add_child(player)
		player.configure(library)
		player.set_physics_process(false)
		player.motor.climbing = true
		for vertical_speed: float in [-90.0, -45.0, 45.0, 90.0]:
			player.velocity = Vector2(0, vertical_speed)
			player.update_animation()
			var frames: SpriteFrames = player.sprite.sprite_frames
			var cycles_per_second: float = (
				frames.get_animation_speed(&"climb") * absf(player.sprite.get_playing_speed())
				/ frames.get_frame_count(&"climb")
			)
			check(
				is_equal_approx(absf(vertical_speed) / cycles_per_second, 32.0),
				"%s: one alternating hand cycle advances two rungs (32 world pixels) at speed %s." % [hero, vertical_speed],
			)
			check(
				signf(player.sprite.get_playing_speed()) == -signf(vertical_speed),
				hero + ": descent reverses the climb sequence.",
			)
		for motion: Vector2 in [Vector2(45, 90), Vector2(90, -90)]:
			player.velocity = motion
			player.update_animation()
			var frames: SpriteFrames = player.sprite.sprite_frames
			var cycles: float = absf(player.sprite.get_playing_speed()) * frames.get_animation_speed(&"climb") / frames.get_frame_count(&"climb")
			check(is_equal_approx(absf(motion.y) / cycles, 32.0), hero + ": sideways input does not accelerate the vertical climb cycle.")
		for horizontal_speed: float in [-90.0, 90.0]:
			player.velocity = Vector2(horizontal_speed, 0)
			player.update_animation()
			check(player.sprite.get_playing_speed() == 1.0, hero + ": sideways ladder exits keep their existing cadence.")
		player.sprite.set_frame_and_progress(2, 0.3)
		player.velocity = Vector2(0, -90)
		player.update_animation()
		check(player.sprite.frame == 2 and is_equal_approx(player.sprite.frame_progress, 0.3), hero + ": direction changes preserve the current pose.")
		player.velocity = Vector2.ZERO
		player.update_animation()
		check(not player.sprite.is_playing() and player.sprite.frame == 2, hero + ": stopping holds the climb pose.")
		player.velocity = Vector2(0, 90)
		player.update_animation()
		check(player.sprite.frame == 2 and player.sprite.get_playing_speed() < 0.0, hero + ": descent resumes from the held pose.")
		player.action = &"primary"
		player.update_animation()
		check(player.sprite.get_playing_speed() == 1.0, hero + ": repair keeps its own playback cadence.")
		player.queue_free()
		await process_frame
	print("CLIMB_CADENCE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
