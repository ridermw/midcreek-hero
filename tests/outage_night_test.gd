extends SceneTree

const LevelBuilder = preload("res://game/level_builder.gd")
const Drone = preload("res://game/hazards/drone.gd")
const LEVEL_SCENE := preload("res://game/level.tscn")
const DT := 1.0 / 60.0

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var drone := Drone.new()
	drone.position = Vector2(400, 300)
	drone.setup()
	var low := 400.0
	var high := 400.0
	var lowest_bob := 0.0
	var highest_bob := 0.0
	for i: int in range(900):
		drone.advance(DT)
		low = minf(low, drone.position.x)
		high = maxf(high, drone.position.x)
		lowest_bob = minf(lowest_bob, drone.bob)
		highest_bob = maxf(highest_bob, drone.bob)
	check(absf(low - 240.0) < 2.0 and absf(high - 560.0) < 2.0, "A drone patrols 5 tiles each way.")
	check(absf(highest_bob - 4.0) < 0.2 and absf(lowest_bob + 4.0) < 0.2, "A drone bobs 4 px.")
	var rect := drone.hit_rect()
	check(rect.size == Vector2(24, 16) and rect.end.y <= drone.position.y - 32.0, "A drone hovers above sliding height.")
	drone.free()

	var level := LEVEL_SCENE.instantiate()
	level.level_path = "res://tests/fixtures/outage_night.level"
	root.add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	level.use_action_override = true
	check(level.error_message.is_empty(), "The outage fixture loads: " + level.error_message)
	check(level.darkness != null and level.darkness.color == level.DARK_COLOR, "Darkness dims the level.")
	check(level.player.get_node_or_null("Flashlight") is PointLight2D, "The player carries a light.")
	var schedule: Array = level.flicker_schedule(3)
	check(schedule.size() == 3 and schedule[0] >= 6.0 and schedule[0] <= 9.0, "The first flicker comes 6 to 9 s in.")
	check(schedule == level.flicker_schedule(3), "The flicker schedule is deterministic.")
	var long_schedule: Array = level.flicker_schedule(80)
	check(long_schedule.size() == 80 and long_schedule.slice(0, 3) == schedule, "The flicker schedule extends without changing its start.")
	check(level.flicker_active_at(long_schedule[60] + 0.5), "Flickers keep coming long after the SLA length.")
	var saw_flicker := false
	var saw_normal_after := false
	for i: int in range(int((schedule[0] + 1.5) * 60.0)):
		level.step(DT)
		var t := (i + 1) * DT
		if t > schedule[0] + 0.1 and t < schedule[0] + 1.1:
			saw_flicker = saw_flicker or level.darkness.color == level.FLICKER_COLOR
		if t > schedule[0] + 1.3:
			saw_normal_after = level.darkness.color == level.DARK_COLOR
	check(saw_flicker and saw_normal_after, "A flicker lasts 1.2 s and returns to normal darkness.")
	level.timer.remaining = 100.0
	var row: Array = level.entities["racks"].filter(func(r) -> bool: return r.task_id == "row")
	check(row.size() == 4, "The final task has 4 racks in one row.")
	for i: int in range(3):
		level.player.position = row[i].position
		level.action_override = {&"repair": true}
		for f: int in range(130):
			level.step(DT)
	level.action_override = {}
	level.step(DT)
	check(not level.tasks.is_done("row"), "3 of 4 racks do not finish the row.")
	level.player.position = row[3].position
	level.action_override = {&"repair": true}
	for f: int in range(130):
		level.step(DT)
	check(level.tasks.is_done("row"), "All 4 racks finish the row.")
	level.queue_free()
	await process_frame
	print("OUTAGE_NIGHT_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
