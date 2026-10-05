extends SceneTree

const LEVEL := preload("res://game/level.tscn")
const MobileInput := preload("res://game/mobile_input.gd")
const LIQUID_PATH := "res://game/hazards/electrified_liquid.gd"
var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check(ResourceLoader.exists(LIQUID_PATH), "Electrified liquid is a distinct fatal hazard.")
	if not ResourceLoader.exists(LIQUID_PATH):
		finish()
		return
	var liquid_script = load(LIQUID_PATH)
	var stateful = liquid_script.new()
	var state_api: bool = stateful.has_method("capture_state") and stateful.has_method("restore_state") and stateful.has_method("reset_motion")
	check(state_api, "Liquid separates progress restoration from motion reset.")
	if state_api:
		stateful.active = false
		var saved: Dictionary = stateful.capture_state()
		stateful.active = true
		stateful.advance(0.4)
		stateful.restore_state(saved)
		stateful.reset_motion()
		check(not stateful.active and stateful._frame == 0, "Resetting animation does not reactivate drained liquid.")
		check(saved == {"active": false}, "Liquid snapshots contain progress, not an exact motion clock.")
	stateful.free()
	for hero: String in ["man", "woman"]:
		var level := LEVEL.instantiate()
		level.character = hero
		level.level_path = "res://tests/fixtures/controller.level"
		level.mobile_input = MobileInput.new()
		root.add_child(level)
		level.set_physics_process(false)
		level.player.set_physics_process(false)
		check(level.error_message.is_empty(), "The fatal contact fixture loads for " + hero)
		var start: Vector2 = level.player.position
		var deaths := [0]
		level.health.died.connect(func() -> void: deaths[0] += 1)
		var liquid = liquid_script.new()
		var overlapping = liquid_script.new()
		level.entity_root.add_child(liquid)
		level.entity_root.add_child(overlapping)
		level.entities["hazards"].append_array([liquid, overlapping])
		for id in ["r1", "r2"]:
			level.tasks.complete(id)
		level.player.position = level.entities["exit"].position
		liquid.position = level.player.position
		overlapping.position = liquid.position
		level.health.damage()
		level.player.hurt()
		level.player.update_animation()
		level.player.sprite.set_frame_and_progress(3, 1.0)
		level.player.sprite.pause()
		check(level.health.is_invulnerable(), "Ordinary invulnerability is active before fatal contact.")
		level.step(0.01)
		check(level.health.segments == 0 and deaths[0] == 1, "Overlapping liquid contacts set health to zero once despite invulnerability.")
		check(level.respawns == 0 and not level.completed, "Fatal contact takes priority over the open exit and delays restoration.")
		check(level.player.locked and level.player.sprite.animation == &"reaction" and level.player.sprite.is_playing(), "The selected hero plays a visible death reaction.")
		check(level.player.sprite.frame == 0, "Fatal contact restarts the reaction even if ordinary hurt already finished.")
		var at_death: Vector2 = level.player.position
		level.player.use_override = true
		level.player.input_override = {"direction": 1.0, "jump_pressed": true, "slide_pressed": true}
		level.player._physics_process(0.2)
		check(level.player.position == at_death, "Death does not move the player or buffer a movement action.")
		level.mobile_input.set_action(&"jump", true)
		level.mobile_input.set_action(&"repair", true)
		Input.action_press(&"move_right")
		level.step(0.49)
		check(level.respawns == 0 and level.health.segments == 0, "Checkpoint restoration does not occur before 0.5 seconds.")
		level.step(0.01)
		check(level.respawns == 1 and level.health.segments == 5 and level.player.position == start, "At 0.5 seconds the checkpoint restores exactly once.")
		check(not level.player.locked and not level.player.frozen and level.player.action == &"", "Recovery clears the death action and movement lock.")
		check(not level.mobile_input.held(&"jump") and not level.mobile_input.held(&"repair"), "Recovery clears transient touch input.")
		check(Input.is_action_pressed(&"move_right"), "Recovery does not synthesize a physical key release.")
		Input.action_release(&"move_right")
		check(not level.player.input_override.has("jump_pressed") and not level.player.input_override.has("slide_pressed"), "Death-time input cannot replay after recovery.")
		level.step(0.1)
		check(level.respawns == 1 and deaths[0] == 1, "The fatal contact cannot request a second restoration.")
		level.player.position = level.entities["checkpoints"][0].position
		liquid.position = level.player.position
		overlapping.position = liquid.position
		level.step(0.01)
		check(level.health.segments == 0 and level.checkpoints.index == -1, "Fatal contact takes priority over activating a checkpoint.")
		level.step(0.5)
		for i in range(5):
			level.health.damage()
			level.health.tick(1.0)
		level.player.position = liquid.position
		level.step(0.01)
		level.step(0.5)
		check(level.respawns == 3 and level.health.segments == 5, "Liquid cannot trap an already pending death at zero health.")
		level.queue_free()
		await process_frame
	finish()


func finish() -> void:
	print("FATAL_LIQUID_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
