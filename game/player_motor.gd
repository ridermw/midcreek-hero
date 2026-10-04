extends RefCounted

const RUN_SPEED := 180.0
const ACCELERATION := 1400.0
const GRAVITY := 1200.0
const JUMP_VELOCITY := 500.0
const JUMP_CUT_VELOCITY := 250.0
const MAX_FALL_SPEED := 600.0
const COYOTE_SECONDS := 0.1
const BUFFER_SECONDS := 0.1

var velocity: Vector2 = Vector2.ZERO
var facing: float = 1.0
var _coyote: float = 0.0
var _buffer: float = 0.0


func reset() -> void:
	velocity = Vector2.ZERO
	_coyote = 0.0
	_buffer = 0.0


func step(input: Dictionary, on_floor: bool, delta: float) -> Vector2:
	var direction := clampf(float(input.get("direction", 0.0)), -1.0, 1.0)
	if direction != 0.0:
		facing = signf(direction)
	_coyote = COYOTE_SECONDS if on_floor else maxf(_coyote - delta, 0.0)
	_buffer = BUFFER_SECONDS if input.get("jump_pressed", false) else maxf(_buffer - delta, 0.0)
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, ACCELERATION * delta)
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		return velocity
	if on_floor:
		velocity.y = 0.0
		return velocity
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	if velocity.y < -JUMP_CUT_VELOCITY and not input.get("jump_held", false):
		velocity.y = -JUMP_CUT_VELOCITY
	return velocity
