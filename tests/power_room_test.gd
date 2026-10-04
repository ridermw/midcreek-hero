extends SceneTree

const LevelBuilder = preload("res://game/level_builder.gd")
const SparkArc = preload("res://game/hazards/spark_arc.gd")
const Lift = preload("res://game/entities/lift.gd")
const LEVEL_SCENE := preload("res://game/level.tscn")
const DT := 1.0 / 60.0

var checks: int = 0
var failures: int = 0
var level: Node2D
var sounds: Array[String] = []


func _initialize() -> void:
	run.call_deferred()


func load_fixture(physics: bool = false) -> void:
	if level != null:
		level.queue_free()
	level = LEVEL_SCENE.instantiate()
	level.level_path = "res://tests/fixtures/power_room.level"
	root.add_child(level)
	if not physics:
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


func panels() -> Array:
	return level.entities["switches"]


func run() -> void:
	var arc := SparkArc.new()
	arc.position = LevelBuilder.cell_to_world(Vector2i(4, 4))
	arc.cell_x = 4
	var states := {}
	for i: int in range(150):
		arc.advance(DT)
		states[arc.state] = states.get(arc.state, 0.0) + DT
		check(arc.active == (arc.state == "on"), "A spark arc hurts only while on.")
	check(absf(states.get("off", 0.0) - 1.4) < 0.05 and absf(states.get("warning", 0.0) - 0.5) < 0.05 and absf(states.get("on", 0.0) - 0.6) < 0.05, "The arc cycle is 1.4 s off, 0.5 s warning, 0.6 s on.")
	check(arc.hit_rect() == Rect2(arc.position + Vector2(-32, -28), Vector2(64, 24)), "The arc covers 64x24 centered on its cell.")
	arc.free()

	check(Lift.offset_at(0.0) == 0.0 and Lift.offset_at(0.4) == 0.0, "A lift pauses 0.5 s at the bottom.")
	check(is_equal_approx(Lift.offset_at(1.5), 48.0), "A lift rises at 48 px/s.")
	check(is_equal_approx(Lift.offset_at(2.5), 96.0) and is_equal_approx(Lift.offset_at(2.9), 96.0), "A lift pauses 0.5 s at the top, 3 tiles up.")
	check(is_equal_approx(Lift.offset_at(4.0), 48.0) and is_equal_approx(Lift.offset_at(5.0), 0.0), "A lift returns down over 2 s.")

	load_fixture()
	check(level.entities["hazards"][0].active, "The fixture includes an initially active arc.")
	level.step(DT)
	check(sounds.count("spark") == 1, "An initially active arc is audible after level listeners connect.")
	for i: int in range(5):
		level.step(DT)
	check(sounds.count("spark") == 1, "An initially active arc plays its startup sound only once.")

	load_fixture()
	level.entities["hazards"][0].cell_x = 0
	for i: int in range(113):
		level.step(DT)
	check(sounds.count("spark") == 0, "An arc stays silent while off or warning.")
	for i: int in range(3):
		level.step(DT)
	check(sounds.count("spark") == 1, "An arc entering its active phase reaches the level audio path.")
	for i: int in range(34):
		level.step(DT)
	check(sounds.count("spark") == 1, "An active arc does not replay its sound every frame.")
	for i: int in range(150):
		level.step(DT)
	check(sounds.count("spark") == 2, "The next arc activation plays another spark sound.")

	load_fixture()
	check(level.error_message.is_empty(), "The power fixture loads: " + level.error_message)
	check(panels().size() == 3 and level.entities["lifts"].size() == 1, "Switch panels and lifts are built.")
	check(panels()[0].order == 1 and panels()[2].order == 3, "Panels know their order.")
	at(Vector2i(12, 4))
	level.step(DT)
	check(level.hud.prompt_label.text.contains("switch 2"), "The HUD names the panel number.")
	tap(&"repair")
	check(not panels()[1].on and "timer_warning" in sounds, "A switch out of order resets the panels.")
	check(level.hud.prompt_label.text.contains("Wrong order"), "The switch error survives the input frame.")
	for i: int in range(30):
		level.step(DT)
	check(level.hud.prompt_label.text.contains("Wrong order"), "The switch error remains readable after releasing the button.")
	for i: int in range(90):
		level.step(DT)
	check(level.hud.prompt_label.text.contains("Throw switch 2"), "The normal switch prompt returns after the error.")
	tap(&"repair")
	at(Vector2i(2, 4))
	for i: int in range(90):
		level.step(DT)
	check(not level.hud.prompt_label.text.contains("Wrong order"), "Leaving the switch clears its expired error feedback.")
	for cell: Vector2i in [Vector2i(10, 4), Vector2i(12, 4)]:
		at(cell)
		level.step(DT)
		tap(&"repair")
	check(panels()[0].on and panels()[1].on and "switch" in sounds, "Switches turn on in order.")
	at(Vector2i(10, 4))
	level.step(DT)
	tap(&"repair")
	check(panels()[0].on and panels()[1].on, "Pressing a lit switch again changes nothing.")
	at(Vector2i(14, 4))
	level.step(DT)
	tap(&"repair")
	check(level.tasks.is_done("b1"), "The third switch in order reboots the switch.")
	load_fixture()
	at(Vector2i(12, 4))
	tap(&"repair")
	at(Vector2i(10, 4))
	tap(&"repair")
	check(panels()[0].on and not level.hud.prompt_label.text.contains("Wrong order"), "A successful switch clears stale error feedback.")
	at(Vector2i(14, 4))
	tap(&"repair")
	for i: int in range(5):
		level.health.damage()
		level.health.tick(1.0)
	level.step(DT)
	check(not level.hud.prompt_label.text.contains("Wrong order"), "Respawning clears stale switch feedback.")
	load_fixture()
	at(Vector2i(10, 4))
	level.step(DT)
	tap(&"repair")
	at(Vector2i(7, 4))
	level.step(DT)
	at(Vector2i(12, 4))
	level.step(DT)
	tap(&"repair")
	for i: int in range(5):
		level.health.damage()
		level.health.tick(1.0)
	level.step(DT)
	check(panels()[0].on and not panels()[1].on, "A respawn keeps switches thrown before the checkpoint only.")

	load_fixture()
	var rack_near: Node2D = null
	for rack in level.entities["racks"]:
		if rack.task_id == "r2":
			rack_near = rack
	rack_near.position = panels()[2].position + Vector2(30, 0)
	at(Vector2i(14, 4))
	level.player.position.x += 20.0
	level.action_override = {&"repair": true}
	for i: int in range(130):
		level.step(DT)
	level.action_override = {}
	check(level.tasks.is_done("r2"), "A rack next to an unfinished switch panel can still be repaired.")

	load_fixture(true)
	level.player.use_override = true
	var lift: Node2D = level.entities["lifts"][0]
	level.player.position = lift.position + Vector2(0, -1)
	var start_y: float = level.player.position.y
	for i: int in range(170):
		await physics_frame
	check(level.player.position.y < start_y - 80.0 and level.player.is_on_floor(), "The player rides a lift up.")
	level.queue_free()
	await process_frame
	print("POWER_ROOM_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
