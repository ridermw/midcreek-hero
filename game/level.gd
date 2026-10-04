extends Node2D

signal finished(result: Dictionary)

const Health = preload("res://game/health.gd")
const SlaTimer = preload("res://game/sla_timer.gd")
const TaskSystem = preload("res://game/task_system.gd")
const CheckpointManager = preload("res://game/checkpoint_manager.gd")
const LevelParser = preload("res://game/level_parser.gd")
const LevelValidator = preload("res://game/level_validator.gd")
const LevelBuilder = preload("res://game/level_builder.gd")
const InputSetup = preload("res://game/input_setup.gd")
const Score = preload("res://game/score.gd")
const Player = preload("res://game/player.gd")
const Hud = preload("res://game/hud.gd")

@export_file("*.level") var level_path: String = "res://levels/00-graybox.level"

var health := Health.new()
var timer := SlaTimer.new()
var tasks := TaskSystem.new()
var checkpoints := CheckpointManager.new()
var level: Dictionary = {}
var entities: Dictionary = {}
var error_message: String = ""
var completed: bool = false
var respawns: int = 0
var use_action_override: bool = false
var action_override: Dictionary = {}
var _respawn_pending: bool = false

@onready var solids: Node2D = $World/Solids
@onready var entity_root: Node2D = $World/Entities
@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera
@onready var hud: Hud = $HUD


func _ready() -> void:
	InputSetup.install()
	if not load_level(level_path):
		hud.show_message(error_message)
		player.set_physics_process(false)
		set_physics_process(false)


func load_level(path: String) -> bool:
	if not FileAccess.file_exists(path):
		error_message = "Level file not found: " + path
		return false
	var parser := LevelParser.new()
	level = parser.parse(FileAccess.get_file_as_string(path), path)
	if level.is_empty():
		error_message = parser.error_message
		return false
	var problems := LevelValidator.new().validate(level)
	if not problems.is_empty():
		error_message = "%s: %s" % [path, "\n".join(PackedStringArray(problems))]
		return false
	var builder := LevelBuilder.new()
	builder.build_solids(level, solids)
	entities = builder.build_entities(level, entity_root)
	if entities.is_empty():
		error_message = "%s: %s" % [path, builder.error_message]
		return false
	for task: Dictionary in level["header"]["tasks"]:
		tasks.add_task(task["id"], task["type"], task["required"], task.get("label", ""))
	health.died.connect(_request_respawn)
	timer.expired.connect(_request_respawn)
	player.respawn(LevelBuilder.cell_to_world(level["player_start"]))
	timer.start(float(level["header"]["sla_seconds"]))
	checkpoints.begin(player.position, timer, tasks)
	hud.bind(health, timer, tasks)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = level["width"] * LevelBuilder.TILE
	camera.limit_bottom = level["height"] * LevelBuilder.TILE
	camera.position = player.position
	return true


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if completed:
		return
	timer.tick(delta)
	health.tick(delta)
	var body := player.hit_rect()
	for hazard in entities["hazards"]:
		hazard.advance(delta)
		if hazard.active and hazard.hit_rect().intersects(body):
			health.damage()
	for pickup in entities["coolant"]:
		var can_heal := health.segments > 0 and health.segments < Health.MAX_SEGMENTS
		if not pickup.taken and can_heal and pickup.hit_rect().intersects(body):
			pickup.take()
			health.heal()
	var feet := player.position
	for i: int in range(entities["checkpoints"].size()):
		var node = entities["checkpoints"][i]
		if node.in_range(feet) and checkpoints.activate(i, node.position, timer, tasks):
			node.set_reached()
	_update_repair(delta, feet)
	var door = entities["exit"]
	door.set_open(tasks.required_done())
	if door.open and door.in_range(feet):
		_finish()
		return
	if _respawn_pending:
		_respawn()
	hud.update_timer()
	camera.position = player.position


func _action_held(action: StringName) -> bool:
	if use_action_override:
		return bool(action_override.get(action, false))
	return Input.is_action_pressed(action)


func _update_repair(delta: float, feet: Vector2) -> void:
	var target = null
	for rack in entities["racks"]:
		if not rack.done and rack.in_range(feet):
			target = rack
			break
	for rack in entities["racks"]:
		if rack != target:
			rack.cancel()
	var holding: bool = target != null and _action_held(&"repair")
	player.locked = holding
	player.action = &"primary" if holding else &""
	if target == null:
		hud.set_prompt("")
	elif not holding:
		target.cancel()
		hud.set_prompt("Hold E or X to repair")
	else:
		hud.set_prompt("Repairing...")
		if target.work(delta):
			_complete_if_all_racks_done(target.task_id)


func _complete_if_all_racks_done(task_id: String) -> void:
	for rack in entities["racks"]:
		if rack.task_id == task_id and not rack.done:
			return
	tasks.complete(task_id)


func _request_respawn() -> void:
	_respawn_pending = true


func _respawn() -> void:
	_respawn_pending = false
	respawns += 1
	player.respawn(checkpoints.restore(timer, tasks))
	health.refill()
	for rack in entities["racks"]:
		rack.set_done(tasks.is_done(rack.task_id))
	hud.refresh_tasks()


func _finish() -> void:
	completed = true
	timer.stop()
	player.locked = true
	var par := float(level["header"]["par_seconds"])
	var result := {
		"elapsed": timer.elapsed,
		"hits": health.hits_taken,
		"respawns": respawns,
		"stars": Score.stars(timer.elapsed, par, health.hits_taken),
	}
	hud.show_message("Level complete. Stars: %d" % result["stars"])
	finished.emit(result)
