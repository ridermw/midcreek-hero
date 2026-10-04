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


func run() -> void:
	InputSetup.install()
	InputSetup.install()
	var bound := true
	for action: StringName in InputSetup.KEYS:
		var kinds := {}
		for event: InputEvent in InputMap.action_get_events(action):
			kinds[event.get_class()] = true
		bound = bound and kinds.has("InputEventKey") and kinds.has("InputEventJoypadButton")
	check(bound, "Every action has a key and a gamepad button.")
	check(InputMap.action_get_events(&"jump").size() == 4, "install does not duplicate events.")
	var floor_body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4000, 32)
	shape.shape = rectangle
	floor_body.position = Vector2(0, 336)
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var player := PLAYER_SCENE.instantiate() as Player
	player.use_override = true
	player.position = Vector2(100, 300)
	root.add_child(player)
	await frames(30)
	check(player.is_on_floor() and absf(player.position.y - 320.0) < 1.0, "Player lands on the floor.")
	player.input_override = {"direction": 1.0}
	await frames(30)
	check(player.position.x > 150.0, "Player runs right.")
	player.input_override = {"direction": 1.0, "jump_pressed": true, "jump_held": true}
	await frames(5)
	check(player.position.y < 300.0 and not player.is_on_floor(), "Player jumps.")
	check(not player.input_override.has("jump_pressed"), "jump_pressed lasts one frame.")
	player.input_override = {}
	await frames(90)
	check(player.is_on_floor(), "Player lands after the jump.")
	player.input_override = {"direction": 1.0}
	player.locked = true
	await frames(20)
	var locked_x := player.position.x
	await frames(20)
	check(player.position.x == locked_x, "A locked player does not move.")
	player.locked = false
	player.position = Vector2(100, 320)
	check(player.hit_rect() == Rect2(91, 272, 18, 48), "hit_rect covers the body above the feet.")
	player.respawn(Vector2(40, 320))
	check(
		player.position == Vector2(40, 320) and player.velocity == Vector2.ZERO and player.motor.velocity == Vector2.ZERO,
		"respawn moves the player and clears velocity.",
	)
	check(Player.choose_clip(true, Vector2.ZERO, false, true, &"primary") == &"reaction", "Hurt shows reaction.")
	check(Player.choose_clip(true, Vector2.ZERO, false, false, &"primary") == &"primary", "Actions show their clip.")
	check(Player.choose_clip(true, Vector2(200, 0), true, false, &"") == &"slide", "Sliding shows slide.")
	check(Player.choose_clip(false, Vector2(100, -50), false, false, &"") == &"jump", "Air shows jump.")
	check(Player.choose_clip(true, Vector2(180, 0), false, false, &"") == &"run", "Full speed shows run.")
	check(Player.choose_clip(true, Vector2(60, 0), false, false, &"") == &"walk", "Low speed shows walk.")
	check(Player.choose_clip(true, Vector2(5, 0), false, false, &"") == &"idle", "Standing shows idle.")
	player.hurt()
	check(player.hurt_remaining > 0.0, "hurt starts the reaction timer.")
	check(player.has_node("Sprite") and not player.has_node("Body"), "The player draws an animated sprite.")
	player.queue_free()
	floor_body.queue_free()
	await process_frame
	print("PLAYER_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
