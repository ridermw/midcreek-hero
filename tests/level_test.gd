extends SceneTree

const LevelBuilder = preload("res://game/level_builder.gd")
const LEVEL_SCENE := preload("res://game/level.tscn")
const DT := 1.0 / 60.0

var checks: int = 0
var failures: int = 0
var level: Node2D


func _initialize() -> void:
	run.call_deferred()


func at(cell: Vector2i) -> void:
	level.player.position = LevelBuilder.cell_to_world(cell)


func run_for(seconds: float) -> void:
	for i: int in range(roundi(seconds * 60.0)):
		level.step(DT)


func hold_repair(seconds: float) -> void:
	level.action_override = {&"repair": true}
	run_for(seconds)
	level.action_override = {}
	level.step(DT)


func run() -> void:
	level = LEVEL_SCENE.instantiate()
	level.level_path = "res://tests/fixtures/controller.level"
	root.add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	level.use_action_override = true
	var results: Array[Dictionary] = []
	level.finished.connect(func(result: Dictionary) -> void: results.append(result))
	var sounds: Array[String] = []
	level.sound.connect(func(sound_name: String) -> void: sounds.append(sound_name))
	check(level.error_message.is_empty() and level.tasks.entries().size() == 3, "Fixture loads.")
	check(level.player.position == Vector2(16, 96) and level.timer.remaining == 120.0, "Player and timer start.")
	check(level.player.sprite.sprite_frames != null, "The player has animation frames.")
	check(level.entities["racks"][0].art != null, "Entities draw generated art.")
	check(level.get_node("World/Far").modulate.v < 0.7, "The far background is darker than gameplay objects.")
	at(Vector2i(0, 2))
	level.step(DT)
	check(level.hud.prompt_label.text == "Run right", "Level prompts show near their column.")
	at(Vector2i(9, 2))
	level.step(DT)
	check(level.hud.prompt_label.text == "", "Level prompts hide away from their column.")
	check(level.health.segments == 4 and level.health.hits_taken == 1, "A cable snag removes 1 segment.")
	check("hit" in sounds, "A hit plays the hit sound.")
	at(Vector2i(12, 2))
	level.step(DT)
	check(level.health.segments == 5 and level.entities["coolant"][0].taken, "Coolant restores 1 segment.")
	at(Vector2i(3, 2))
	level.action_override = {&"repair": true}
	level.step(DT)
	check(level.player.locked and level.player.action == &"primary", "Holding repair locks the player.")
	run_for(2.1)
	check(level.tasks.is_done("r1"), "2 s of repair completes the task.")
	check("repair_tick" in sounds and "repair_done" in sounds, "Repair plays tick and done sounds.")
	level.action_override = {}
	level.step(DT)
	check(not level.player.locked, "Releasing repair unlocks the player.")
	at(Vector2i(6, 2))
	level.step(DT)
	check(level.checkpoints.index == 0 and level.entities["checkpoints"][0].reached, "Checkpoint 1 activates.")
	check("checkpoint" in sounds, "A checkpoint plays its sound.")
	at(Vector2i(15, 2))
	level.step(DT)
	check(level.checkpoints.index == 1, "Checkpoint 2 activates.")
	at(Vector2i(18, 2))
	hold_repair(2.1)
	check(level.entities["racks"][1].done and not level.tasks.is_done("r2"), "A row task needs every rack.")
	for i: int in range(5):
		level.health.damage()
		level.health.tick(1.0)
	level.step(DT)
	check(
		level.player.position == Vector2(496, 96)
		and level.health.segments == 5
		and not level.entities["racks"][1].done
		and level.respawns == 1,
		"Death restores checkpoint 2, full health, and the earlier task state.",
	)
	level.timer.remaining = 0.5
	run_for(1.0)
	check(level.respawns == 2 and level.timer.remaining > 30.0, "SLA expiry restores the checkpoint timer.")
	at(Vector2i(29, 2))
	level.step(DT)
	check(not level.completed and not level.entities["exit"].open, "The exit stays closed with open tasks.")
	at(Vector2i(18, 2))
	hold_repair(2.1)
	at(Vector2i(20, 2))
	hold_repair(2.1)
	check(level.tasks.is_done("r2") and level.entities["exit"].open, "Finishing r2 opens the exit.")
	at(Vector2i(29, 2))
	level.step(DT)
	check(level.completed and results.size() == 1, "Standing at the open exit finishes the level.")
	check("door_open" in sounds and "win" in sounds and "fail" in sounds and "heal" in sounds, "Exit, win, fail, and heal sounds play.")
	check(
		results[0]["stars"] == 2 and results[0]["respawns"] == 2 and results[0]["hits"] == 6,
		"Under par with 6 hits gives 2 stars.",
	)
	check(results[0]["optional_done"] == 0 and results[0]["optional_total"] == 1, "Results count optional tasks.")
	level.queue_free()
	level = LEVEL_SCENE.instantiate()
	level.level_path = "res://tests/fixtures/controller.level"
	root.add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	for id: String in ["r1", "r2"]:
		level.tasks.complete(id)
	level.timer.remaining = 0.01
	at(Vector2i(29, 2))
	level.step(DT)
	check(not level.completed and level.respawns == 1, "SLA expiry at the open exit restarts instead of finishing.")
	at(Vector2i(6, 2))
	level.timer.remaining = 0.01
	level.step(DT)
	check(level.checkpoints.index == -1, "A failed step does not activate a checkpoint.")
	level.player.position = Vector2(100, 2000)
	level.step(DT)
	check(level.respawns == 3, "Falling out of the level restarts at the checkpoint.")
	level.queue_free()
	var graybox := LEVEL_SCENE.instantiate()
	root.add_child(graybox)
	check(
		graybox.error_message.is_empty() and graybox.entities["racks"].size() == 3,
		"The gray box level loads by default.",
	)
	graybox.queue_free()
	await process_frame
	print("LEVEL_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
