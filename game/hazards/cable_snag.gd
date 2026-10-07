extends Node2D
## A stationary cable pile that patrols its floor like a walking mushroom.
## The pile body (64 px) stays on supported floor between walls and edges,
## and at most RANGE px from its authored cell.

const Patrol = preload("res://game/hazards/patrol.gd")
const SIZE := Vector2(64, 16)
const ART_RECT := Rect2(-32, -32, 64, 32)
const TILE := 32
const SPEED := 40.0
const RANGE := 48.0
const MIN_SPAN := 32.0

var active: bool = true
var art: RefCounted
## Patrol bounds for the pile center; the builder sets them from the level grid.
var bounds := Vector2.ZERO
var patrol: Patrol
var direction: float:
	get:
		return patrol.direction if patrol != null else 1.0
var _time: float = 0.0
var _frame: int = -1


## Returns (min_x, max_x) for the pile center at `cell`, from walls and floor edges.
static func span(level: Dictionary, cell: Vector2i) -> Vector2:
	var solids: Dictionary = level["solids"]
	var width := int(level["width"])
	var left := cell.x
	while _free(solids, width, Vector2i(left - 1, cell.y)):
		left -= 1
	var right := cell.x
	while _free(solids, width, Vector2i(right + 1, cell.y)):
		right += 1
	var center := float(cell.x * TILE + TILE / 2)
	var half := SIZE.x / 2.0
	return Vector2(maxf(center - RANGE, left * TILE + half), minf(center + RANGE, (right + 1) * TILE - half))


static func _free(solids: Dictionary, width: int, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and not solids.has(cell) and solids.has(cell + Vector2i.DOWN)


func _ready() -> void:
	setup()


func setup() -> void:
	var limits := bounds
	if limits == Vector2.ZERO:
		limits = Vector2(position.x - RANGE, position.x + RANGE)
	# A pocket narrower than the patrol minimum keeps the pile at its authored position.
	if limits.y - limits.x < MIN_SPAN:
		limits = Vector2(position.x, position.x)
	patrol = Patrol.new(position.x, minf(limits.x, position.x), maxf(limits.y, position.x), SPEED)


func advance(delta: float) -> void:
	position.x = patrol.step(delta)
	if art != null:
		_time += delta
		var next: int = int(_time * 4.0) % art.frame_count("hazards", "cable-snag")
		if next != _frame:
			_frame = next
			queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func reset_motion() -> void:
	patrol.reset()
	position.x = patrol.x
	_time = 0.0
	_frame = 0
	reset_physics_interpolation()
	queue_redraw()


func _draw() -> void:
	if art != null:
		var frame: int = maxi(_frame, 0)
		draw_texture_rect(art.texture("hazards", "cable-snag", frame), ART_RECT, false)
		return
	draw_rect(Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y), Color(0.95, 0.55, 0.1))
