extends Node2D

const Patrol = preload("res://game/hazards/patrol.gd")

const RANGE := 160.0
const SPEED := 70.0
const HOVER := 52.0
const BOB := 4.0
const SIZE := Vector2(24, 16)

var active: bool = true
var art: RefCounted
var patrol: Patrol
var direction: float:
	get:
		return patrol.direction if patrol != null else 1.0
var bob: float = 0.0
var _time: float = 0.0
var _frame: int = -1


func _ready() -> void:
	setup()


func setup() -> void:
	patrol = Patrol.new(position.x, position.x - RANGE, position.x + RANGE, SPEED)


func advance(delta: float) -> void:
	position.x = patrol.step(delta)
	_time += delta
	bob = sin(_time * TAU) * BOB
	var next := int(_time * 8.0) % 4
	if next != _frame:
		_frame = next
	queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-SIZE.x / 2.0, -HOVER - SIZE.y / 2.0 + bob), SIZE)


func reset_motion() -> void:
	patrol.reset()
	position.x = patrol.x
	bob = 0.0
	_time = 0.0
	_frame = 0
	reset_physics_interpolation()
	queue_redraw()


func _draw() -> void:
	var center := Vector2(0, -HOVER + bob)
	if art != null and art.has("hazards", "drone"):
		draw_texture(art.texture("hazards", "drone", maxi(_frame, 0)), center - Vector2(16, 12), Color.WHITE)
	else:
		draw_rect(Rect2(center - SIZE / 2.0, SIZE), Color(0.3, 0.3, 0.35))
	draw_circle(center + Vector2(direction * 6.0, 2), 2.0, Color(1.0, 0.2, 0.2))
