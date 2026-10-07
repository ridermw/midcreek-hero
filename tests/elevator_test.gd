# godot_test_args: --fixed-fps 60
extends SceneTree

const LEVEL = preload("res://game/level.tscn")
const Lift = preload("res://game/entities/lift.gd")
const DT := 1.0 / 60.0
const EXPECTED_RISE := 160.0
const EXPECTED_WIDTH := 96.0
const SITES := [
	{"slug": "04-power-room", "index": 0, "col": 42, "landing_first": 44},
	{"slug": "04-power-room", "index": 1, "col": 94, "landing_first": 96},
	{"slug": "04-power-room", "index": 2, "col": 157, "landing_first": 159},
	{"slug": "04-power-room", "index": 3, "col": 282, "landing_first": 284},
	{"slug": "05-outage-night", "index": 0, "col": 59, "landing_first": 61},
	{"slug": "05-outage-night", "index": 1, "col": 220, "landing_first": 222},
]

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func lift_constants() -> Dictionary:
	var lift := Lift.new()
	var constants: Dictionary = lift.get_script().get_script_constant_map()
	lift.free()
	return constants


func run() -> void:
	var constants := lift_constants()
	check(constants.get("RISE_TILES", 0) == 5, "The runtime lift contract is 5 tiles.")
	check(is_equal_approx(float(constants.get("RISE", 0.0)), EXPECTED_RISE), "The runtime lift rise is 160 px.")
	check(is_equal_approx(float(constants.get("SPEED", 0.0)), 64.0), "The runtime lift speed is 64 px/s.")
	check(is_equal_approx(float(constants.get("PAUSE", 0.0)), 1.0), "The runtime lift pause is 1.0 s.")
	check(is_equal_approx(float(constants.get("SIZE", Vector2.ZERO).x), EXPECTED_WIDTH), "The lift platform is 96 px wide.")
	for hero: String in ["man", "woman"]:
		await expect_board_ride_and_leave(hero)
		await expect_fall_mid_ride(hero)
		await expect_death_during_ride_resets_lower(hero)
	print("ELEVATOR_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func make_level(slug: String, hero: String) -> Node:
	var level := LEVEL.instantiate()
	level.character = hero
	level.level_path = "res://levels/%s.level" % slug
	root.add_child(level)
	check(level.error_message.is_empty(), "%s loads for %s: %s" % [slug, hero, level.error_message])
	level.player.use_override = true
	return level


func lift_for(level: Node, site: Dictionary) -> Node2D:
	return level.entities["lifts"][int(site["index"])]


func top_y(lift: Node2D) -> float:
	return lift.base_y - EXPECTED_RISE


func expect_board_ride_and_leave(hero: String) -> void:
	var site: Dictionary = SITES[0]
	var level := make_level(site["slug"], hero)
	var lift := lift_for(level, site)
	level.player.respawn(lift.position + Vector2(0.0, -1.0))
	var start_y: float = level.player.position.y
	for _frame: int in range(235):
		level.player.input_override = {}
		await physics_frame
	check(level.player.is_on_floor() and level.player.position.y < start_y - 140.0, "%s rides the elevator to the 5 tile upper story." % hero)
	for _frame: int in range(90):
		level.player.input_override = {"direction": 1.0}
		await physics_frame
	check(level.player.position.x > float(site["landing_first"]) * 32.0 + 20.0 and level.player.position.y <= top_y(lift) + 16.0, "%s leaves the elevator on the upper landing." % hero)
	level.queue_free()
	await process_frame


func expect_fall_mid_ride(hero: String) -> void:
	var site: Dictionary = SITES[0]
	var level := make_level(site["slug"], hero)
	var lift := lift_for(level, site)
	level.player.respawn(lift.position + Vector2(0.0, -1.0))
	for frame: int in range(210):
		level.player.input_override = {"direction": -1.0} if frame > 90 else {}
		await physics_frame
	check(level.player.position.y >= lift.base_y - 8.0 and level.health.segments > 0, "%s can fall from a moving elevator and recover on the lower floor." % hero)
	level.queue_free()
	await process_frame


func expect_death_during_ride_resets_lower(hero: String) -> void:
	var site: Dictionary = SITES[0]
	var level := make_level(site["slug"], hero)
	var lift := lift_for(level, site)
	var base := lift.position
	level.player.respawn(lift.position + Vector2(0.0, -1.0))
	for _frame: int in range(105):
		level.player.input_override = {}
		await physics_frame
	check(lift.position.y < base.y - 20.0, "%s is on a moving lift before the death reset." % hero)
	level._begin_fatal_death()
	for _frame: int in range(45):
		await physics_frame
		if level.respawns == 1:
			break
	check(level.respawns == 1, "%s death during a ride restores the checkpoint once." % hero)
	check(lift.position == base and lift._time <= DT, "%s death during a ride resets the lift to the lower landing and lower pause." % hero)
	check(absf(level.player.position.x - lift.position.x) > EXPECTED_WIDTH / 2.0, "%s does not restore on the platform or in the shaft." % hero)
	level.queue_free()
	await process_frame


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)