extends SceneTree

const LevelBuilder = preload("res://game/level_builder.gd")
const HeatVent = preload("res://game/hazards/heat_vent.gd")
const LEVEL_SCENE := preload("res://game/level.tscn")
const DT := 1.0 / 60.0

var checks: int = 0
var failures: int = 0
var level: Node2D
var sounds: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func load_fixture() -> void:
	if level != null:
		level.queue_free()
	level = LEVEL_SCENE.instantiate()
	level.level_path = "res://tests/fixtures/hot_aisle.level"
	root.add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	level.use_action_override = true
	sounds.clear()
	level.sound.connect(func(sound_name: String) -> void: sounds.append(sound_name))


func at(cell: Vector2i) -> void:
	level.player.position = LevelBuilder.cell_to_world(cell)


func run_for(seconds: float, actions: Dictionary = {}) -> void:
	level.action_override = actions
	for i: int in range(roundi(seconds * 60.0)):
		level.step(DT)
	level.action_override = {}
	level.step(DT)


func rack_for(task_id: String) -> Node2D:
	for rack in level.entities["racks"]:
		if rack.task_id == task_id:
			return rack
	return null


func die() -> void:
	for i: int in range(5):
		level.health.damage()
		level.health.tick(1.0)
	level.step(DT)


func run() -> void:
	var vent := HeatVent.new()
	vent.position = LevelBuilder.cell_to_world(Vector2i(3, 2))
	vent.cell_x = 3
	check(is_equal_approx(vent.offset, fmod(3 * 0.37, 2.9)), "The vent phase offset depends on its column.")
	var states := {}
	var time := 0.0
	while time < 2.9:
		vent.advance(DT)
		states[vent.state] = states.get(vent.state, 0.0) + DT
		check(vent.active == (vent.state == "on"), "A vent hurts only while on.")
		time += DT
	check(absf(states.get("off", 0.0) - 1.5) < 0.05 and absf(states.get("warning", 0.0) - 0.4) < 0.05 and absf(states.get("on", 0.0) - 1.0) < 0.05, "The vent cycle is 1.5 s off, 0.4 s warning, 1.0 s on.")
	check(vent.hit_rect() == Rect2(vent.position + Vector2(-14, -64), Vector2(28, 64)), "The plume covers 28x64 above the vent.")
	vent.free()

	load_fixture()
	check(level.error_message.is_empty(), "The hot aisle fixture loads: " + level.error_message)
	check(level.entities["parts"].size() == 1 and level.entities["parts"][0].kind == "psu", "The fetch part is built.")
	at(Vector2i(3, 2))
	run_for(3.0)
	check(level.health.hits_taken >= 1, "Standing in a vent plume causes damage.")
	load_fixture()
	at(Vector2i(6, 2))
	run_for(1.0, {&"repair": true})
	check(not level.tasks.is_done("f1") and level.hud.prompt_label.text.contains("PSU"), "A fetch rack asks for its part.")
	at(Vector2i(12, 2))
	level.step(DT)
	check(level.carried_part == "f1" and level.entities["parts"][0].taken and "pickup" in sounds, "Touching the part picks it up.")
	check(level.hud.carry_label.text.contains("PSU"), "The HUD shows the carried part.")
	at(Vector2i(6, 2))
	run_for(0.6, {&"repair": true})
	check(level.tasks.is_done("f1") and level.carried_part == "" and "deliver" in sounds, "Holding repair at the rack delivers the part.")
	at(Vector2i(15, 2))
	run_for(1.0, {&"repair": true})
	check(rack_for("d1").progress == 0.0 and level.hud.prompt_label.text.contains("Diagnose first"), "A diagnose rack ignores repair before diagnosis.")
	run_for(DT, {&"diagnose": true})
	check(rack_for("d1").diagnosed and "diagnose" in sounds and level.player.action == &"secondary", "Diagnose marks the rack and plays the meter clip.")
	run_for(0.9)
	run_for(2.1, {&"repair": true})
	check(level.tasks.is_done("d1"), "After the 0.8 s diagnosis, repair completes the task.")

	load_fixture()
	at(Vector2i(9, 2))
	level.step(DT)
	at(Vector2i(12, 2))
	level.step(DT)
	check(level.carried_part == "f1", "The part is carried after checkpoint 1.")
	at(Vector2i(15, 2))
	run_for(DT, {&"diagnose": true})
	die()
	check(level.carried_part == "" and not level.entities["parts"][0].taken, "A respawn puts back a part picked up after the checkpoint.")
	check(not rack_for("d1").diagnosed, "A respawn clears a diagnosis made after the checkpoint.")
	at(Vector2i(12, 2))
	level.step(DT)
	at(Vector2i(15, 2))
	run_for(DT, {&"diagnose": true})
	at(Vector2i(18, 2))
	level.step(DT)
	die()
	check(level.carried_part == "f1" and level.entities["parts"][0].taken, "A part picked up before the checkpoint stays carried.")
	check(rack_for("d1").diagnosed, "A diagnosis made before the checkpoint stays.")
	level.queue_free()
	await process_frame
	print("HOT_AISLE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
