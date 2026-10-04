extends SceneTree

const Feel = preload("res://game/feel.gd")
const Hud = preload("res://game/hud.gd")
const LevelBuilder = preload("res://game/level_builder.gd")
const LEVEL_SCENE := preload("res://game/level.tscn")
const DT := 1.0 / 60.0

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	check(Feel.shake_amplitude(0.0) == 4.0, "Shake starts at 4 px.")
	check(is_equal_approx(Feel.shake_amplitude(0.125), 2.0), "Shake decays linearly.")
	check(Feel.shake_amplitude(0.25) == 0.0 and Feel.shake_amplitude(1.0) == 0.0, "Shake ends after 0.25 s.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var offset := Feel.shake_offset(0.05, rng)
	check(absf(offset.x) <= Feel.shake_amplitude(0.05) and absf(offset.y) <= Feel.shake_amplitude(0.05), "Shake offsets stay inside the amplitude.")
	check(Feel.timer_pulse(40.0, 0.3) == 1.0, "No pulse above 30 s.")
	var pulses: Array[float] = []
	for i: int in range(10):
		pulses.append(Feel.timer_pulse(20.0, i * 0.1))
	check(pulses.min() < 0.8 and pulses.max() == 1.0, "The timer pulses below 30 s.")

	var level := LEVEL_SCENE.instantiate()
	level.level_path = "res://tests/fixtures/controller.level"
	root.add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	level.use_action_override = true
	level.player.position = LevelBuilder.cell_to_world(Vector2i(9, 2))
	var before: float = level.timer.remaining
	level.step(DT)
	check(level.health.hits_taken == 1 and level.hit_stop_remaining > 0.0, "A hit starts a hit stop.")
	check(level.shake_remaining > 0.0, "A hit starts a screen shake.")
	var during: float = level.timer.remaining
	level.step(DT)
	level.step(DT)
	check(level.timer.remaining == during, "The SLA timer holds during the 0.05 s hit stop.")
	for i: int in range(5):
		level.step(DT)
	check(level.timer.remaining < during, "Play resumes after the hit stop.")
	check(level.player.frozen == false, "The player thaws after the hit stop.")
	for i: int in range(20):
		level.step(DT)
	check(level.camera.offset == Vector2.ZERO, "The camera settles after the shake.")
	level.player.position = LevelBuilder.cell_to_world(Vector2i(3, 2))
	level.action_override = {&"repair": true}
	for i: int in range(130):
		level.step(DT)
	check(level.get_node("World").find_children("*", "CPUParticles2D", true, false).size() >= 1, "A finished repair throws sparks.")
	level.queue_free()
	await process_frame
	print("FEEL_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
