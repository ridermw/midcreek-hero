extends Node2D

signal finished(result: Dictionary)
signal sound(sound_name: String)

const REPAIR_TICK_SECONDS := 0.4

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
const SpriteLibrary = preload("res://game/sprite_library.gd")
const HeroAnimations = preload("res://game/animation_library.gd")
const BACKGROUNDS := {"cold-aisle": "res://art/cel-shift/environment/layers/"}
const PARALLAX := {"far": 0.2, "equipment": 0.6}
const BACKGROUND_TINT := {"far": Color(0.42, 0.47, 0.56), "equipment": Color(0.55, 0.6, 0.68)}

@export_file("*.level") var level_path: String = "res://levels/00-graybox.level"
@export_enum("man", "woman") var character: String = "man"

var health := Health.new()
var timer := SlaTimer.new()
var tasks := TaskSystem.new()
var checkpoints := CheckpointManager.new()
var art := SpriteLibrary.new()
var animations := HeroAnimations.new()
var level: Dictionary = {}
var entities: Dictionary = {}
var error_message: String = ""
var completed: bool = false
var respawns: int = 0
var use_action_override: bool = false
var action_override: Dictionary = {}
var _respawn_pending: bool = false
var _repair_tick: float = 0.0

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
	if not art.load_all():
		error_message = art.error_message
		return false
	if not animations.load_manifest():
		error_message = animations.error_message
		return false
	if not _build_background(String(level["header"]["background"])):
		return false
	player.character = character
	player.configure(animations)
	var builder := LevelBuilder.new()
	builder.art = art
	builder.build_solids(level, solids)
	entities = builder.build_entities(level, entity_root)
	if entities.is_empty():
		error_message = "%s: %s" % [path, builder.error_message]
		return false
	for task: Dictionary in level["header"]["tasks"]:
		tasks.add_task(task["id"], task["type"], task["required"], task.get("label", ""))
	health.died.connect(_request_respawn)
	timer.expired.connect(_request_respawn)
	timer.warning.connect(sound.emit.bind("timer_warning"))
	player.sound.connect(sound.emit)
	player.respawn(LevelBuilder.cell_to_world(level["player_start"]))
	timer.start(float(level["header"]["sla_seconds"]))
	checkpoints.begin(player.position, timer, tasks)
	hud.art = art
	for segment: TextureRect in hud.segments:
		segment.texture = art.texture("ui", "health-full")
		segment.custom_minimum_size = segment.texture.get_size() * 2
	hud.bind(health, timer, tasks)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = level["width"] * LevelBuilder.TILE
	camera.limit_bottom = level["height"] * LevelBuilder.TILE
	camera.position = player.position
	return true


func _build_background(background: String) -> bool:
	if not BACKGROUNDS.has(background):
		error_message = "Pending artwork: unknown background set: " + background
		return false
	var floor_y := float(level["height"] * LevelBuilder.TILE)
	var z := -30
	for layer: String in PARALLAX:
		var path: String = BACKGROUNDS[background] + layer + ".png"
		if not ResourceLoader.exists(path):
			error_message = "Pending artwork: missing background layer: " + path
			return false
		var texture := load(path) as Texture2D
		var parallax := Parallax2D.new()
		parallax.name = layer.capitalize()
		parallax.scroll_scale = Vector2(PARALLAX[layer], 1.0)
		parallax.repeat_size = Vector2(texture.get_width(), 0)
		parallax.repeat_times = 3
		parallax.z_index = z
		parallax.modulate = BACKGROUND_TINT[layer]
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(0, floor_y - texture.get_height())
		parallax.add_child(sprite)
		$World.add_child(parallax)
		$World.move_child(parallax, 0)
		z += 10
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
		if hazard.active and hazard.hit_rect().intersects(body) and health.damage():
			player.hurt()
			sound.emit("hit")
	if _out_of_bounds():
		_request_respawn()
	if _respawn_pending:
		_respawn()
		hud.update_timer()
		camera.position = player.position
		return
	for pickup in entities["coolant"]:
		var can_heal := health.segments > 0 and health.segments < Health.MAX_SEGMENTS
		if not pickup.taken and can_heal and pickup.hit_rect().intersects(body):
			pickup.take()
			health.heal()
			sound.emit("heal")
	var feet := player.position
	for i: int in range(entities["checkpoints"].size()):
		var node = entities["checkpoints"][i]
		if node.in_range(feet) and checkpoints.activate(i, node.position, timer, tasks):
			node.set_reached()
			sound.emit("checkpoint")
	_update_repair(delta, feet)
	var door = entities["exit"]
	if tasks.required_done() and not door.open:
		sound.emit("door_open")
	door.set_open(tasks.required_done())
	if door.open and door.in_range(feet):
		_finish()
		return
	hud.update_timer()
	camera.position = player.position


func _out_of_bounds() -> bool:
	var width := float(level["width"] * LevelBuilder.TILE)
	var height := float(level["height"] * LevelBuilder.TILE)
	var feet := player.position
	return feet.y > height + 64.0 or feet.x < -64.0 or feet.x > width + 64.0


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
		hud.set_prompt(_level_prompt(feet))
	elif not holding:
		target.cancel()
		hud.set_prompt("Hold E or X to repair")
	else:
		hud.set_prompt("Repairing...")
		_repair_tick -= delta
		if _repair_tick <= 0.0:
			_repair_tick = REPAIR_TICK_SECONDS
			sound.emit("repair_tick")
		if target.work(delta):
			sound.emit("repair_done")
			_complete_if_all_racks_done(target.task_id)


func _level_prompt(feet: Vector2) -> String:
	var column := int(floorf(feet.x / LevelBuilder.TILE))
	for prompt: Dictionary in level["header"].get("prompts", []):
		if absi(column - int(prompt["x"])) <= 3:
			return String(prompt["text"])
	return ""


func _complete_if_all_racks_done(task_id: String) -> void:
	for rack in entities["racks"]:
		if rack.task_id == task_id and not rack.done:
			return
	tasks.complete(task_id)


func _request_respawn() -> void:
	_respawn_pending = true


func _respawn() -> void:
	_respawn_pending = false
	sound.emit("fail")
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
		"optional_done": 0,
		"optional_total": 0,
	}
	for entry: Dictionary in tasks.entries():
		if not entry["required"]:
			result["optional_total"] += 1
			if entry["done"]:
				result["optional_done"] += 1
	sound.emit("win")
	hud.show_message("Level complete. Stars: %d" % result["stars"])
	hud.show_stars(result["stars"])
	finished.emit(result)
