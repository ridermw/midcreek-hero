extends RefCounted

const RUN_SPEED := 180.0
const ACCELERATION := 1400.0
const GRAVITY := 1200.0
const JUMP_VELOCITY := 500.0
const JUMP_CUT_VELOCITY := 250.0
const MAX_FALL_SPEED := 600.0
const COYOTE_SECONDS := 0.1
const BUFFER_SECONDS := 0.1
const SLIDE_SPEED := 260.0
const SLIDE_SECONDS := 0.45
const WALL_SLIDE_SPEED := 90.0
const WALL_JUMP_PUSH := 220.0
const WALL_JUMP_VELOCITY := 460.0
const WALL_JUMP_LOCK_SECONDS := 0.15
const CLIMB_SPEED := 90.0

var velocity: Vector2 = Vector2.ZERO
var facing: float = 1.0
var sliding: bool = false
var climbing: bool = false
var _coyote: float = 0.0
var _buffer: float = 0.0
var _slide_remaining: float = 0.0
var _wall_lock: float = 0.0


func reset() -> void:
	velocity = Vector2.ZERO
	_coyote = 0.0
	_buffer = 0.0
	sliding = false
	climbing = false
	_slide_remaining = 0.0
	_wall_lock = 0.0


func step(input: Dictionary, context: Variant, delta: float) -> Vector2:
	var ctx: Dictionary = context if context is Dictionary else {"on_floor": bool(context)}
	var on_floor := bool(ctx.get("on_floor", false))
	var direction := clampf(float(input.get("direction", 0.0)), -1.0, 1.0)
	var vertical := clampf(float(input.get("vertical", 0.0)), -1.0, 1.0)
	_coyote = COYOTE_SECONDS if on_floor else maxf(_coyote - delta, 0.0)
	_buffer = BUFFER_SECONDS if input.get("jump_pressed", false) else maxf(_buffer - delta, 0.0)
	_wall_lock = maxf(_wall_lock - delta, 0.0)
	if climbing and (not ctx.get("on_ladder", false) or _buffer > 0.0):
		climbing = false
		if _buffer > 0.0:
			_buffer = 0.0
			_coyote = 0.0
			velocity = Vector2(direction * RUN_SPEED, -JUMP_VELOCITY)
			return velocity
	if not climbing and ctx.get("on_ladder", false) and vertical != 0.0 and not sliding:
		climbing = true
	if climbing:
		velocity = Vector2(direction * CLIMB_SPEED, vertical * CLIMB_SPEED)
		return velocity
	if sliding:
		_slide_remaining -= delta
		if _slide_remaining <= 0.0 and not ctx.get("ceiling_blocked", false):
			sliding = false
		else:
			velocity = Vector2(facing * SLIDE_SPEED, 0.0 if on_floor else minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED))
			return velocity
	if on_floor and input.get("slide_pressed", false):
		sliding = true
		_slide_remaining = SLIDE_SECONDS
		velocity = Vector2(facing * SLIDE_SPEED, 0.0)
		return velocity
	if direction != 0.0 and _wall_lock <= 0.0:
		facing = signf(direction)
	if _wall_lock <= 0.0:
		velocity.x = move_toward(velocity.x, direction * RUN_SPEED, ACCELERATION * delta)
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		return velocity
	var normal := float(ctx.get("wall_normal_x", 0.0))
	var pressing_wall: bool = not on_floor and ctx.get("on_wall", false) and normal != 0.0 and direction == -signf(normal)
	if pressing_wall and _buffer > 0.0:
		_buffer = 0.0
		_wall_lock = WALL_JUMP_LOCK_SECONDS
		facing = signf(normal)
		velocity = Vector2(normal * WALL_JUMP_PUSH, -WALL_JUMP_VELOCITY)
		return velocity
	if on_floor:
		velocity.y = 0.0
		return velocity
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	if pressing_wall and velocity.y > WALL_SLIDE_SPEED:
		velocity.y = WALL_SLIDE_SPEED
	if velocity.y < -JUMP_CUT_VELOCITY and not input.get("jump_held", false):
		velocity.y = -JUMP_CUT_VELOCITY
	return velocity
