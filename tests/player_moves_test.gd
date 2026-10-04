extends SceneTree

const InputSetup = preload("res://game/input_setup.gd")
const Player = preload("res://game/player.gd")
const PLAYER_SCENE := preload("res://game/player.tscn")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame


func block(rect: Rect2, layers: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layers
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.position = rect.get_center()
	body.add_child(shape)
	root.add_child(body)
	return body


func keys(action: StringName) -> Array[int]:
	var result: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			result.append((event as InputEventKey).physical_keycode)
	return result


func run() -> void:
	InputSetup.install()
	check(keys(&"jump") == [KEY_SPACE], "Jump uses Space only.")
	check(KEY_W in keys(&"move_up") and KEY_UP in keys(&"move_up"), "W and Up climb.")
	check(KEY_S in keys(&"move_down") and KEY_DOWN in keys(&"move_down"), "S and Down descend.")
	check(KEY_C in keys(&"slide") and KEY_SHIFT in keys(&"slide"), "C and Shift slide.")
	var floor_body := block(Rect2(-2000, 320, 4000, 32), 1 | 4)
	var tray := block(Rect2(300, 272, 200, 16), 1 | 4)
	var player := PLAYER_SCENE.instantiate() as Player
	player.use_override = true
	player.position = Vector2(100, 319)
	root.add_child(player)
	await frames(10)
	check(player.body_height() == 64.0, "Standing body is 64 tall.")
	player.position = Vector2(250, 319)
	player.input_override = {"direction": 1.0, "slide_pressed": true}
	await frames(2)
	check(player.motor.sliding and player.body_height() == 24.0, "Sliding shrinks the body to 24.")
	check(player.hit_rect().size.y == 24.0, "The hit box follows the slide.")
	player.input_override = {"direction": 1.0}
	var low_under_tray := false
	var cleared := false
	for i: int in range(120):
		await physics_frame
		if i == 30 and player.position.x > 310.0 and player.position.x < 490.0:
			low_under_tray = player.motor.sliding and player.body_height() == 24.0
		if player.position.x > 520.0:
			cleared = true
			break
	check(low_under_tray, "The player stays low while a tray blocks standing, past the 0.45 s slide.")
	check(cleared, "A slide carries the player under a low tray.")
	await frames(40)
	check(not player.motor.sliding and player.body_height() == 64.0, "The player stands after leaving the tray.")
	player.position = Vector2(250, 319)
	player.motor.reset()
	player.input_override = {"direction": 1.0, "slide_pressed": true}
	await frames(18)
	check(player.position.x > 310.0 and player.position.x < 490.0 and player.motor.sliding, "The player is sliding under the tray before an action lock.")
	player.locked = true
	var locked_x := player.position.x
	await frames(40)
	check(absf(player.position.x - locked_x) < 1.0, "An action lock stops horizontal movement during a slide.")
	check(player.motor.sliding and player.body_height() == 24.0, "A locked player stays low when the tray blocks standing.")
	player.locked = false
	player.input_override = {}
	await frames(60)
	check(player.position.x > 520.0 and player.body_height() == 64.0, "The player can clear the tray after the action lock ends.")
	tray.queue_free()
	await frames(3)
	player.position = Vector2(700, 319)
	player.motor.reset()
	await frames(3)
	player.on_ladder = true
	player.input_override = {"vertical": -1.0}
	var start_y := player.position.y
	await frames(30)
	check(player.motor.climbing and player.position.y < start_y - 30.0, "Holding up on a ladder climbs.")
	player.on_ladder = false
	player.input_override = {}
	await frames(60)
	check(not player.motor.climbing and player.is_on_floor(), "Leaving the ladder drops the player back to the floor.")
	var wall := block(Rect2(900, 60, 32, 260), 1 | 4)
	player.position = Vector2(890, 200)
	player.motor.reset()
	player.input_override = {"direction": 1.0, "jump_held": true}
	await frames(3)
	check(player.is_on_wall_only(), "The player touches a wall while airborne before jumping.")
	var sounds: Array[String] = []
	player.sound.connect(func(sound_name: String) -> void: sounds.append(sound_name))
	player.input_override = {"direction": 1.0, "jump_pressed": true, "jump_held": true}
	await frames(5)
	check(sounds == ["jump"] and player.velocity.x < 0.0, "A wall jump plays one jump sound while kicking away.")
	wall.queue_free()
	player.queue_free()
	floor_body.queue_free()
	await process_frame
	print("PLAYER_MOVES_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
