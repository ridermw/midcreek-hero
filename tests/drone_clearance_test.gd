# godot_test_args: --fixed-fps 60
extends SceneTree

const LEVEL = preload("res://game/level.tscn")
const Drone = preload("res://game/hazards/drone.gd")
const MobileInput = preload("res://game/mobile_input.gd")
const FLOOR_Y := 224.0
var checks := 0
var failures := 0


class TouchClock:
	extends Node
	var touch: RefCounted

	func _physics_process(_delta: float) -> void:
		touch.advance()


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var drone := Drone.new()
	drone.position = Vector2(400, FLOOR_Y)
	root.add_child(drone)
	check(drone.has_method("beam_rect"), "The drone exposes one beam rectangle for drawing and damage.")
	if drone.has_method("beam_rect"):
		var beam: Rect2 = drone.beam_rect()
		check(drone.hit_rect() == beam, "The hit rectangle is the drawn beam rectangle.")
		check(is_equal_approx(beam.end.y, FLOOR_Y - 36.0) and is_equal_approx(beam.position.y, FLOOR_Y - 200.0), "The beam spans 36 to 200 px above the floor: %s" % beam)
		drone.advance(0.37)
		check(drone.hit_rect() == drone.beam_rect() and is_equal_approx(drone.hit_rect().end.y, FLOOR_Y - 36.0), "Bobbing does not move the beam bottom.")
	drone.queue_free()
	for hero: String in ["man", "woman"]:
		await expect(hero, "jump", true)
		await expect(hero, "wall jump", true)
		for source: String in ["key", "joypad", "touch"]:
			await expect(hero, "slide " + source, false)
	print("DRONE_CLEARANCE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func expect(hero: String, move: String, hit: bool) -> void:
	var level := LEVEL.instantiate()
	level.character = hero
	level.level_path = "res://tests/fixtures/drone.level"
	root.add_child(level)
	check(level.error_message.is_empty(), "The drone fixture loads: " + level.error_message)
	var drone: Node2D = level.entities["hazards"][0]
	drone.patrol.speed = 0.0
	var player: Node = level.player
	var touch := MobileInput.new()
	var clock := TouchClock.new()
	clock.touch = touch
	clock.process_physics_priority = -100
	root.add_child(clock)
	if move == "wall jump":
		player.respawn(Vector2(352 + 10, FLOOR_Y - 70))
	else:
		player.respawn(Vector2(drone.position.x + 140, FLOOR_Y))
	await physics_frame
	var passed := false
	for frame: int in range(150):
		var gap: float = player.position.x - drone.position.x
		if move == "jump" or move == "wall jump":
			player.use_override = true
			var input := {"direction": -1.0}
			if move == "jump" and frame == 18:
				input = {"direction": -1.0, "jump_pressed": true, "jump_held": true}
			elif move == "jump" and frame > 18:
				input["jump_held"] = true
			if move == "wall jump" and frame == 10:
				input = {"direction": -1.0, "jump_pressed": true, "jump_held": true}
			elif move == "wall jump" and frame > 10:
				input = {"direction": 1.0, "jump_held": true}
			player.input_override = input
		else:
			var source := move.trim_prefix("slide ")
			var slide_now := gap <= 40.0 and gap > 30.0
			if source == "key":
				press_key(KEY_A, true)
				press_key(KEY_C, slide_now)
			elif source == "joypad":
				var axis := InputEventJoypadMotion.new()
				axis.axis = JOY_AXIS_LEFT_X
				axis.axis_value = -1.0
				Input.parse_input_event(axis)
				var button := InputEventJoypadButton.new()
				button.button_index = JOY_BUTTON_B
				button.pressed = slide_now
				Input.parse_input_event(button)
			else:
				level.mobile_input = touch
				player.mobile_input = touch
				touch.set_action(&"move_left", true)
				touch.set_action(&"slide", slide_now)
		await physics_frame
		passed = passed or player.position.x < drone.position.x - 40.0
		if level.health.hits_taken > 0 or (passed and frame > 60):
			break
	var took_hit: bool = level.health.hits_taken > 0
	if hit:
		check(took_hit, "%s: a %s into the drone beam is hit." % [hero, move])
	else:
		check(not took_hit and passed, "%s: a %s passes under the drone without a hit (x=%.0f)." % [hero, move, player.position.x])
	release_all()
	touch.clear()
	clock.queue_free()
	level.queue_free()
	await process_frame


func press_key(key: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = down
	Input.parse_input_event(event)


func release_all() -> void:
	press_key(KEY_A, false)
	press_key(KEY_C, false)
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.0
	Input.parse_input_event(axis)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_B
	Input.parse_input_event(button)


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)
