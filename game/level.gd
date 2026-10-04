extends Node2D

signal finished(result: Dictionary)
signal sound(sound_name: String)

const REPAIR_TICK_SECONDS := 0.4
const DIAGNOSE_SECONDS := 0.8
const PART_LABELS := {"psu": "PSU", "dimm": "DIMM"}
const DARK_COLOR := Color(0.3, 0.32, 0.4)
const FLICKER_COLOR := Color(0.12, 0.12, 0.18)
const FLICKER_SECONDS := 1.2
const BUTTON_LABELS := {&"repair": "E / X", &"diagnose": "Q / Y", &"jump": "Space / A"}

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
const CablePort = preload("res://game/entities/cable_port.gd")
const Feel = preload("res://game/feel.gd")
const SpriteLibrary = preload("res://game/sprite_library.gd")
const HeroAnimations = preload("res://game/animation_library.gd")
const BACKGROUNDS := {
	"cold-aisle": "res://art/cel-shift/environment/layers/",
	"hot-aisle": "res://art/cel-shift/environment/hot-aisle/",
	"cable-jungle": "res://art/cel-shift/environment/cable-jungle/",
	"power-room": "res://art/cel-shift/environment/power-room/",
	"outage-night": "res://art/cel-shift/environment/outage-night/",
}
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
var carried_part: String = ""
var _diagnose_remaining: float = 0.0
var _previous_actions: Dictionary = {}
var _pressed_actions: Dictionary = {}
var darkness: CanvasModulate
var hit_stop_remaining: float = 0.0
var shake_remaining: float = 0.0
var _shake_rng := RandomNumberGenerator.new()
var _flicker_times: Array = []
var _clock: float = 0.0

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
	if level["header"].get("darkness", false):
		_build_darkness()
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
	checkpoints.begin(player.position, timer, tasks, capture_state())
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


func flicker_schedule(count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(level["header"]["name"]))
	var times: Array = []
	var at := 0.0
	for i: int in range(count):
		at += rng.randf_range(6.0, 9.0)
		times.append(at)
	return times


func _build_darkness() -> void:
	darkness = CanvasModulate.new()
	darkness.name = "Darkness"
	darkness.color = DARK_COLOR
	add_child(darkness)
	var light := PointLight2D.new()
	light.name = "Flashlight"
	var gradient := GradientTexture2D.new()
	gradient.width = 320
	gradient.height = 320
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(1.0, 0.5)
	var colors := Gradient.new()
	colors.set_color(0, Color(1, 1, 1, 1))
	colors.set_color(1, Color(1, 1, 1, 0))
	gradient.gradient = colors
	light.texture = gradient
	light.energy = 1.1
	light.position = Vector2(0, -40)
	player.add_child(light)
	_flicker_times = flicker_schedule(4)


func flicker_active_at(time: float) -> bool:
	while _flicker_times.is_empty() or _flicker_times.back() < time:
		_flicker_times = flicker_schedule(_flicker_times.size() + 8)
	for start: float in _flicker_times:
		if start > time:
			return false
		if time < start + FLICKER_SECONDS:
			return true
	return false


func _update_darkness(delta: float) -> void:
	if darkness == null:
		return
	_clock += delta
	darkness.color = FLICKER_COLOR if flicker_active_at(_clock) else DARK_COLOR


func _update_shake(delta: float) -> void:
	if shake_remaining <= 0.0:
		camera.offset = Vector2.ZERO
		return
	shake_remaining = maxf(shake_remaining - delta, 0.0)
	camera.offset = Feel.shake_offset(Feel.SHAKE_SECONDS - shake_remaining, _shake_rng) if shake_remaining > 0.0 else Vector2.ZERO


func _sparks(at: Vector2) -> void:
	$World.add_child(Feel.spark_burst(at + Vector2(0, -60)))


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
	_sample_actions()
	_update_darkness(delta)
	_update_shake(delta)
	if hit_stop_remaining > 0.0:
		hit_stop_remaining -= delta
		player.frozen = hit_stop_remaining > 0.0
		return
	timer.tick(delta)
	health.tick(delta)
	var body := player.hit_rect()
	for hazard in entities["hazards"]:
		hazard.advance(delta)
		if hazard.active and hazard.hit_rect().intersects(body) and health.damage():
			player.hurt()
			sound.emit("hit")
			hit_stop_remaining = Feel.HIT_STOP_SECONDS
			shake_remaining = Feel.SHAKE_SECONDS
			player.frozen = true
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
		if node.in_range(feet) and checkpoints.activate(i, node.position, timer, tasks, capture_state()):
			node.set_reached()
			sound.emit("checkpoint")
	for part in entities["parts"]:
		if not part.taken and carried_part.is_empty() and part.hit_rect().intersects(body):
			part.take()
			carried_part = part.task_id
			hud.set_carry("Carrying " + PART_LABELS[part.kind])
			sound.emit("pickup")
	var cell := Vector2i(floori(feet.x / LevelBuilder.TILE), floori((feet.y - 1.0) / LevelBuilder.TILE))
	player.on_ladder = cell in level["ladders"]
	if not _update_switches(feet) and not _update_ports(delta, feet):
		_update_repair(delta, feet)
	_show_switch_prompt(feet)
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


func capture_state() -> Dictionary:
	var state := {"carried_part": carried_part}
	for group: String in ["racks", "parts", "ports", "switches", "coolant"]:
		var states: Array = []
		for node in entities[group]:
			states.append(node.capture_state())
		state[group] = states
	return state


func restore_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	carried_part = String(state["carried_part"])
	var label := ""
	for part in entities["parts"]:
		if part.task_id == carried_part:
			label = "Carrying " + PART_LABELS[part.kind]
	hud.set_carry(label)
	_diagnose_remaining = 0.0
	for group: String in ["racks", "parts", "ports", "switches", "coolant"]:
		for i: int in range(entities[group].size()):
			entities[group][i].restore_state(state[group][i])


func _action_held(action: StringName) -> bool:
	if use_action_override:
		return bool(action_override.get(action, false))
	return Input.is_action_pressed(action)


func _sample_actions() -> void:
	for action: StringName in [&"repair", &"diagnose", &"jump"]:
		var held := _action_held(action)
		_pressed_actions[action] = held and not _previous_actions.get(action, false)
		_previous_actions[action] = held


func _action_pressed(action: StringName) -> bool:
	if use_action_override:
		return _pressed_actions.get(action, false)
	return Input.is_action_just_pressed(action)


func _update_switches(feet: Vector2) -> bool:
	var panel = null
	for candidate in entities["switches"]:
		if not tasks.is_done(candidate.task_id) and candidate.in_range(feet):
			panel = candidate
			break
	if panel == null:
		return false
	player.locked = false
	player.action = &""
	var group: Array = entities["switches"].filter(func(p) -> bool: return p.task_id == panel.task_id)
	var next := 1
	for other in group:
		if other.on:
			next = maxi(next, other.order + 1)
	if not _action_pressed(&"repair") or panel.on:
		return false
	if panel.order != next:
		for other in group:
			other.set_on(false)
		sound.emit("timer_warning")
		hud.set_prompt("Wrong order. Start again at switch 1")
		return true
	panel.set_on(true)
	sound.emit("switch")
	if next == group.size():
		tasks.complete(panel.task_id)
		sound.emit("repair_done")
	return true


func _show_switch_prompt(feet: Vector2) -> void:
	if player.locked:
		return
	for panel in entities["switches"]:
		if not tasks.is_done(panel.task_id) and panel.in_range(feet) and not panel.on:
			hud.set_prompt("Throw switch %d: press E or X" % panel.order)
			return


func _update_ports(delta: float, feet: Vector2) -> bool:
	var port = null
	for candidate in entities["ports"]:
		if not candidate.done and (candidate.state == "active" or candidate.in_range(feet)):
			port = candidate
			break
	if port == null:
		return false
	if port.state == "idle":
		if not port.in_range(feet):
			return false
		player.locked = false
		player.action = &""
		hud.set_prompt("Press E or X to reseat the cable")
		if _action_pressed(&"repair"):
			port.begin()
			player.locked = true
			player.action = &"primary"
			hud.set_prompt("Press " + BUTTON_LABELS[port.current_button()])
			sound.emit("menu_move")
		return true
	player.locked = true
	player.action = &"primary"
	for button: StringName in CablePort.BUTTONS:
		if _action_pressed(button):
			var result: String = port.press(button)
			if result == "done":
				tasks.complete(port.task_id)
				sound.emit("repair_done")
			elif result == "ok":
				sound.emit("repair_tick")
			else:
				sound.emit("timer_warning")
				player.locked = false
				player.action = &""
			break
	if port.state == "active" and port.advance(delta):
		sound.emit("timer_warning")
		player.locked = false
		player.action = &""
	if port.state == "active":
		hud.set_prompt("Press %s  (%d of 3)" % [BUTTON_LABELS[port.current_button()], port.step + 1])
	elif not port.done:
		hud.set_prompt("Press E or X to reseat the cable")
	return true


func _part_label(rack) -> String:
	return PART_LABELS.get(rack.part_kind, "part")


func _update_repair(delta: float, feet: Vector2) -> void:
	var target = null
	for rack in entities["racks"]:
		if not rack.done and rack.in_range(feet):
			target = rack
			break
	for rack in entities["racks"]:
		if rack != target:
			rack.cancel()
	if _diagnose_remaining > 0.0:
		_diagnose_remaining -= delta
		player.locked = true
		player.action = &"secondary"
		return
	if target != null and target.kind == "diagnose_repair" and not target.diagnosed and _action_pressed(&"diagnose"):
		target.diagnosed = true
		target.queue_redraw()
		_diagnose_remaining = DIAGNOSE_SECONDS
		player.locked = true
		player.action = &"secondary"
		hud.set_prompt("Diagnosing...")
		sound.emit("diagnose")
		return
	var blocked := ""
	if target != null and target.kind == "diagnose_repair" and not target.diagnosed:
		blocked = "Diagnose first (Q / Y)"
	elif target != null and target.kind == "fetch" and carried_part != target.task_id:
		blocked = "Bring the %s to this rack" % _part_label(target)
	var holding: bool = target != null and blocked.is_empty() and _action_held(&"repair")
	player.locked = holding
	player.action = &"primary" if holding else &""
	if target == null:
		hud.set_prompt(_level_prompt(feet))
	elif not blocked.is_empty():
		target.cancel()
		hud.set_prompt(blocked)
	elif not holding:
		target.cancel()
		var verb := "install the %s" % _part_label(target) if target.kind == "fetch" else "repair"
		hud.set_prompt("Hold E or X to " + verb)
	else:
		hud.set_prompt("Working...")
		_repair_tick -= delta
		if _repair_tick <= 0.0:
			_repair_tick = REPAIR_TICK_SECONDS
			sound.emit("repair_tick")
		if target.work(delta):
			if target.kind == "fetch":
				carried_part = ""
				hud.set_carry("")
				sound.emit("deliver")
			else:
				sound.emit("repair_done")
			_sparks(target.position)
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
	restore_state(checkpoints.level_state)
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
