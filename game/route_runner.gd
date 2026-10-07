extends RefCounted

const PlayerMotor = preload("res://game/player_motor.gd")
const ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down", "jump", "repair", "diagnose", "slide"
]
# until_hazard prediction: piles within this range of the hero or the target, for at most 8 s, with 4 px
# of clearance, and 0.3 s of running after landing.
const SIMULATION_RANGE := 640.0
const SIMULATION_FRAMES := 480
const CLEAR_MARGIN := 4.0
const LANDED_FRAMES := 18

var steps: Array = []
var index: int = 0
var failed: bool = false
var error_message: String = ""
var _step_time: float = 0.0
var _step_frames: int = 0
var _slide_held: bool = false
var _slide_pending: bool = false
var _committed: bool = false


func _init(route_steps: Array) -> void:
	steps = route_steps
	for i: int in range(steps.size()):
		var problem := _validate(steps[i])
		if not problem.is_empty():
			error_message = "Route step %d: %s" % [i + 1, problem]
			failed = true
			return


func done() -> bool:
	return index >= steps.size()


func apply(level: Object, delta: float) -> void:
	level.player.use_override = true
	level.use_action_override = true
	if failed or done():
		_set_input(level, [], false)
		return
	var step: Dictionary = steps[index]
	var first := _step_frames == 0
	if step.has("tap"):
		_set_input(level, [step["tap"]], true)
		_advance()
		return
	if step.has("wait"):
		_set_input(level, [], false)
		_tick(delta, float(step["wait"]))
		return
	var held: Array = step["hold"]
	if step.has("until_hazard"):
		_until_hazard(level, step, held, delta, first)
		return
	if step.has("until_y"):
		var target := float(step["until_y"])
		var direction := -1.0 if "move_up" in held else 1.0
		if (level.player.position.y - target) * direction >= 0.0:
			_advance()
			apply(level, delta)
			return
		_set_input(level, held, first)
		_step_time += delta
		_step_frames += 1
		if _step_time > float(step["max_seconds"]):
			failed = true
			error_message = "Route step %d did not reach y=%.0f within %.1f s (y=%.0f)." % [
				index + 1, float(step["until_y"]), float(step["max_seconds"]), level.player.position.y
			]
		return
	if step.has("until_x"):
		var target := float(step["until_x"])
		var direction := -1.0 if "move_left" in held else 1.0
		if (level.player.position.x - target) * direction >= 0.0:
			_advance()
			apply(level, delta)
			return
		_set_input(level, held, first)
		_step_time += delta
		_step_frames += 1
		if _step_time > float(step["max_seconds"]):
			failed = true
			error_message = "Route step %d did not reach x=%.0f within %.1f s (x=%.0f)." % [
				index + 1, target, float(step["max_seconds"]), level.player.position.x
			]
		return
	_set_input(level, held, first)
	_tick(delta, float(step["seconds"]))


func _tick(delta: float, seconds: float) -> void:
	_step_time += delta
	_step_frames += 1
	if _step_time >= seconds - 0.0001:
		_advance()


# Waits in place until running to `gap` px before the patrolling pile at the
# authored x, then jumping, is predicted to clear every nearby pile. Then it
# runs to the gap and hands off to the next step, which is the jump.
func _until_hazard(level: Object, step: Dictionary, held: Array, delta: float, first: bool) -> void:
	var target: Node2D = null
	for hazard in level.entities["hazards"]:
		if "patrol" in hazard and hazard.patrol != null and is_equal_approx(hazard.patrol.origin, float(step["until_hazard"])):
			target = hazard
	if target == null:
		failed = true
		error_message = "Route step %d has no patrolling hazard at x=%.0f." % [index + 1, float(step["until_hazard"])]
		return
	var gap := float(step["gap"])
	var on_floor: bool = level.player.is_on_floor()
	if target.position.x - level.player.position.x <= gap and _committed and on_floor:
		_advance()
		apply(level, delta)
		return
	if on_floor and not _committed:
		_committed = jump_clear(level, target, gap)
	var moves: Array = held
	if not _committed and on_floor:
		# Wait only on floor that no patrolling pile can reach.
		moves = []
		var x: float = level.player.position.x
		if in_zone(level, target, x):
			moves = ["move_left"]
		else:
			for hazard in level.entities["hazards"]:
				if hazard != target and in_zone(level, hazard, x):
					moves = ["move_right"]
	_set_input(level, moves, first)
	_step_time += delta
	_step_frames += 1
	if _step_time > float(step["max_seconds"]):
		failed = true
		error_message = "Route step %d found no clear jump over x=%.0f within %.1f s." % [index + 1, float(step["until_hazard"]), float(step["max_seconds"])]


## True when the full patrol range of a pile can reach a hero at `x`.
static func in_zone(level: Object, hazard: Node2D, x: float) -> bool:
	if not ("patrol" in hazard) or hazard.patrol == null or hazard.has_method("beam_rect"):
		return false
	var reach: float = hazard.SIZE.x / 2.0 + level.player.BODY_SIZE.x / 2.0 + CLEAR_MARGIN
	return x > hazard.patrol.min_x - reach and x < hazard.patrol.max_x + reach


## Predicts a run to `gap` px before `target` and a full jump, against the
## deterministic patrol of every nearby pile. Drones are passed by sliding.
static func jump_clear(level: Object, target: Node2D, gap: float) -> bool:
	var dt := 1.0 / 60.0
	var player: Node2D = level.player
	var half: float = player.BODY_SIZE.x / 2.0
	var x: float = player.position.x
	var speed: float = player.velocity.x
	var piles: Array[Dictionary] = []
	for hazard in level.entities["hazards"]:
		var near: bool = absf(hazard.position.x - x) < SIMULATION_RANGE or absf(hazard.position.x - target.position.x) < SIMULATION_RANGE
		if "patrol" in hazard and hazard.patrol != null and not hazard.has_method("beam_rect") and (near or hazard == target):
			piles.append({"node": hazard, "x": hazard.position.x, "direction": hazard.patrol.direction})
	var height := 0.0
	var rise := 0.0
	var jumping := false
	var landed := 0
	for frame: int in range(SIMULATION_FRAMES):
		speed = minf(PlayerMotor.RUN_SPEED, speed + PlayerMotor.ACCELERATION * dt)
		x += speed * dt
		var target_x := 0.0
		for pile: Dictionary in piles:
			var patrol: RefCounted = pile["node"].patrol
			pile["x"] += pile["direction"] * patrol.speed * dt
			if pile["x"] >= patrol.max_x:
				pile["x"] = patrol.max_x
				pile["direction"] = -1.0
			elif pile["x"] <= patrol.min_x:
				pile["x"] = patrol.min_x
				pile["direction"] = 1.0
			if pile["node"] == target:
				target_x = pile["x"]
		if not jumping and target_x - x <= gap:
			jumping = true
			rise = PlayerMotor.JUMP_VELOCITY
		if jumping and landed == 0:
			rise -= PlayerMotor.GRAVITY * dt
			height += rise * dt
			if height <= 0.0:
				height = 0.0
				landed = 1
		elif landed > 0:
			landed += 1
		for pile: Dictionary in piles:
			var size: Vector2 = pile["node"].SIZE
			if absf(x - pile["x"]) < size.x / 2.0 + half + CLEAR_MARGIN and height < size.y + CLEAR_MARGIN:
				return false
		if landed >= LANDED_FRAMES and x > target_x:
			return true
	return false


func _advance() -> void:
	index += 1
	_step_time = 0.0
	_step_frames = 0
	_committed = false


func _set_input(level: Object, held: Array, first_frame: bool) -> void:
	var direction := 0.0
	if "move_left" in held:
		direction -= 1.0
	if "move_right" in held:
		direction += 1.0
	var vertical := 0.0
	if "move_up" in held:
		vertical -= 1.0
	if "move_down" in held:
		vertical += 1.0
	var input := {"direction": direction, "vertical": vertical}
	if "jump" in held:
		input["jump_held"] = true
		if first_frame:
			input["jump_pressed"] = true
	var slide_held := "slide" in held
	if slide_held and not _slide_held:
		_slide_pending = true
	_slide_held = slide_held
	# A slide needs floor contact, so a press made in the air waits for landing.
	if _slide_pending and (not level.player.has_method("is_on_floor") or level.player.is_on_floor()):
		input["slide_pressed"] = true
		_slide_pending = false
	level.player.input_override = input
	var actions := {}
	for action: String in ["repair", "diagnose", "jump"]:
		if action in held:
			actions[StringName(action)] = true
	level.action_override = actions


func _validate(step: Variant) -> String:
	if not step is Dictionary:
		return "must be an object."
	var kinds := 0
	for kind: String in ["hold", "tap", "wait"]:
		if step.has(kind):
			kinds += 1
	if kinds != 1:
		return "needs exactly one of hold, tap, or wait."
	var allowed: Array = ["tap"] if step.has("tap") else ["wait"]
	if step.has("hold"):
		allowed = ["hold", "until_x", "max_seconds"] if step.has("until_x") else ["hold", "seconds"]
		if step.has("until_y") and not step.has("until_x"):
			allowed = ["hold", "until_y", "max_seconds"]
		if step.has("until_hazard"):
			allowed = ["hold", "until_hazard", "gap", "max_seconds"]
	for key: Variant in step:
		if key not in allowed:
			return "unsupported field '%s'." % key
	if step.has("tap"):
		return "" if step["tap"] is String and String(step["tap"]) in ACTIONS else "unknown tap action."
	if step.has("wait"):
		return "" if _is_duration(step["wait"]) else "wait needs a finite duration of 0 or more."
	if not step["hold"] is Array:
		return "hold needs an action list."
	for action: Variant in step["hold"]:
		if not action is String or String(action) not in ACTIONS:
			return "unknown action '%s'." % action
	if step.has("until_hazard"):
		for key: String in ["until_hazard", "gap"]:
			var number: Variant = step[key] if step.has(key) else null
			if not ((number is float or number is int) and is_finite(float(number))):
				return key + " must be a finite number."
		if not _is_duration(step.get("max_seconds")) or float(step["max_seconds"]) <= 0.0:
			return "until_hazard needs a positive max_seconds."
		if step["hold"] != ["move_right"]:
			return "until_hazard holds only move_right."
		return ""
	if step.has("until_y"):
		if step.has("seconds") or step.has("until_x"):
			return "hold cannot combine until_y with seconds or until_x."
		var target: Variant = step["until_y"]
		if not ((target is float or target is int) and is_finite(float(target))):
			return "until_y must be a finite number."
		if not _is_duration(step.get("max_seconds")) or float(step["max_seconds"]) <= 0.0:
			return "until_y needs a positive max_seconds."
		if ("move_up" in step["hold"]) == ("move_down" in step["hold"]):
			return "until_y needs exactly one of move_up or move_down."
		return ""
	if step.has("until_x"):
		var value: Variant = step["until_x"]
		if not ((value is float or value is int) and is_finite(float(value))):
			return "until_x must be a finite number."
		if not _is_duration(step.get("max_seconds")) or float(step["max_seconds"]) <= 0.0:
			return "until_x needs a positive max_seconds."
		if ("move_left" in step["hold"]) == ("move_right" in step["hold"]):
			return "until_x needs exactly one of move_left or move_right."
		return ""
	return "" if _is_duration(step.get("seconds")) else "hold needs seconds of 0 or more, or until_x or until_y with max_seconds."


static func _is_duration(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0
