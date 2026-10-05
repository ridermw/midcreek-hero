# godot_test_args: --fixed-fps 120
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
		player.action = &"primary"
		player.update_animation()
		player.sprite.set_frame_and_progress(player.sprite.sprite_frames.get_frame_count(&"primary") - 1, 0.999)
		# Rendering can cross the clip boundary before the next physics update.
		await process_frame
		await process_frame
		check(player.sprite.is_playing(), hero + ": held repair never stops at the loop boundary.")
		check(player.sprite.frame == 0, hero + ": repair wraps without waiting for update_animation.")
		check(player.sprite.frame_progress > 0.0, hero + ": repair preserves elapsed time across the boundary.")
		check(
			not library.variants[StringName(hero + "-midcreek")].get_animation_loop(&"primary"),
			hero + ": gameplay does not change the shared single action clip.",
		)
		player.sprite.play(&"primary")
		player.sprite.set_frame_and_progress(2, 0.5)
		player.update_animation()
		check(player.sprite.frame == 2 and player.sprite.frame_progress == 0.5, hero + ": held repair preserves an active phase.")
		player.sprite.speed_scale = 0.0
		await process_frame
		await process_frame
		check(player.sprite.frame == 2 and player.sprite.frame_progress == 0.5, hero + ": hit stop freezes repair.")
		player.sprite.speed_scale = 1.0
		player.action = &""
		player.update_animation()
		check(player.sprite.animation != &"primary", hero + ": releasing repair leaves the loop.")
		player.queue_free()
		await process_frame
	print("ANIMATION_CADENCE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
