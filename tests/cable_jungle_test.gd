extends SceneTree

const LevelBuilder = preload("res://game/level_builder.gd")
const CablePort = preload("res://game/entities/cable_port.gd")
const MovingSnag = preload("res://game/hazards/moving_snag.gd")
const PlayerMotor = preload("res://game/player_motor.gd")
const LEVEL_SCENE := preload("res://game/level.tscn")
const DT := 1.0 / 60.0
const KEYS := {&"repair": "E", &"diagnose": "Q", &"jump": "Space"}

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
	level.level_path = "res://tests/fixtures/cable_jungle.level"
	root.add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	level.use_action_override = true
	sounds.clear()
	level.sound.connect(func(sound_name: String) -> void: sounds.append(sound_name))


func at(cell: Vector2i) -> void:
	level.player.position = LevelBuilder.cell_to_world(cell)


func tap(action: StringName) -> void:
	level.action_override = {action: true}
	level.step(DT)
	level.action_override = {}
	level.step(DT)


func die() -> void:
	for i: int in range(5):
		level.health.damage()
		level.health.tick(1.0)
	level.step(DT)


func run() -> void:
	var sequence := CablePort.sequence_for("c1")
	check(sequence.size() == 3, "A reseat sequence has 3 buttons.")
	var n := absi(hash("c1")) % 27
	check(sequence == [CablePort.BUTTONS[n / 9], CablePort.BUTTONS[(n / 3) % 3], CablePort.BUTTONS[n % 3]], "The sequence comes from the task id hash.")
	var port := CablePort.new()
	port.task_id = "c1"
	port.begin()
	check(port.press(sequence[0]) == "ok" and port.step == 1, "The right button advances the sequence.")
	check(port.press(&"diagnose" if sequence[1] != &"diagnose" else &"repair") == "wrong" and port.state == "idle", "A wrong button restarts the sequence.")
	port.begin()
	check(port.advance(1.01), "A window times out after 1.0 s.")
	check(port.state == "idle", "A timeout restarts the sequence.")
	port.begin()
	for button: StringName in sequence:
		port.press(button)
	check(port.done, "All 3 buttons in time reseat the cable.")
	port.free()

	var snag := MovingSnag.new()
	snag.position = Vector2(200, 100)
	snag.setup()
	var low := 200.0
	var high := 200.0
	for i: int in range(600):
		snag.advance(DT)
		low = minf(low, snag.position.x)
		high = maxf(high, snag.position.x)
	check(absf(low - (200.0 - 96.0)) < 2.0 and absf(high - (200.0 + 96.0)) < 2.0, "A moving snag patrols 3 tiles each way.")
	snag.free()

	var climber := PlayerMotor.new()
	climber.step({"vertical": -1.0}, {"on_ladder": true}, DT)
	check(climber.step({"vertical": -1.0, "direction": 1.0}, {"on_ladder": true}, DT).x == PlayerMotor.CLIMB_SPEED, "A climber can step sideways off a ladder.")

	load_fixture()
	check(level.error_message.is_empty(), "The cable fixture loads: " + level.error_message)
	check(level.entities["ports"].size() == 1 and level.entities["hazards"][0] is MovingSnag, "Ports and moving snags are built.")
	check(level.get_node("World/Solids").find_children("Ladder*", "", true, false).size() == 4, "Ladder cells are drawn.")
	at(Vector2i(10, 4))
	level.step(DT)
	check(level.player.on_ladder, "Standing at a ladder sets on_ladder.")
	at(Vector2i(9, 4))
	level.step(DT)
	check(not level.player.on_ladder, "Leaving the ladder clears on_ladder.")
	at(Vector2i(15, 4))
	level.step(DT)
	check(level.hud.prompt_model()["description"].contains("reseat"), "A cable port offers a reseat.")
	tap(&"repair")
	check(level.entities["ports"][0].state == "active" and level.player.locked, "Pressing repair starts the sequence and locks the player.")
	check(level.hud.prompt_graphic.text == KEYS[sequence[0]], "The HUD shows the next graphical button.")
	for i: int in range(sequence.size()):
		level.action_override = {sequence[i]: true}
		level.step(DT)
		level.action_override = {}
		if i < 2:
			check(is_equal_approx(level.entities["ports"][0].window_remaining, 1.0), "Each accepted button starts a full second for the next input.")
			for frame: int in range(59):
				level.step(DT)
			check(level.entities["ports"][0].state == "active", "The next reseat window remains open until a full second has elapsed.")
		else:
			level.step(DT)
	check(level.tasks.is_done("c1") and "repair_done" in sounds and not level.player.locked, "The right sequence completes the reseat task.")
	load_fixture()
	at(Vector2i(15, 4))
	level.step(DT)
	tap(&"repair")
	for i: int in range(70):
		level.step(DT)
	check(level.entities["ports"][0].state == "idle" and not level.tasks.is_done("c1"), "A timeout in the level restarts the sequence.")
	load_fixture()
	at(Vector2i(3, 4))
	level.step(DT)
	at(Vector2i(15, 4))
	level.step(DT)
	tap(&"repair")
	for button: StringName in sequence:
		tap(button)
	check(level.tasks.is_done("c1") and level.entities["ports"][0].done, "The reseat is complete after the first checkpoint.")
	die()
	check(not level.tasks.is_done("c1") and not level.entities["ports"][0].done and level.entities["ports"][0].state == "idle", "A respawn undoes a reseat completed after the checkpoint.")
	at(Vector2i(15, 4))
	level.step(DT)
	tap(&"repair")
	for button: StringName in sequence:
		tap(button)
	at(Vector2i(18, 4))
	level.step(DT)
	check(level.checkpoints.index == 1 and level.tasks.is_done("c1"), "The next checkpoint records the completed reseat.")
	die()
	check(level.tasks.is_done("c1") and level.entities["ports"][0].done, "A reseat completed before the next checkpoint survives a respawn.")
	level.queue_free()
	await process_frame
	print("CABLE_JUNGLE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
