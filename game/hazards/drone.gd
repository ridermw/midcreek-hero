extends Node2D

const RANGE := 160.0
const SPEED := 70.0
const HOVER := 52.0
const BOB := 4.0
const SIZE := Vector2(24, 16)

var active: bool = true
var art: RefCounted
var origin_x: float = 0.0
var direction: float = 1.0
var bob: float = 0.0
var _time: float = 0.0
var _frame: int = -1


func _ready() -> void:
	setup()


func setup() -> void:
	origin_x = position.x


func advance(delta: float) -> void:
	position.x += direction * SPEED * delta
	if position.x >= origin_x + RANGE:
		position.x = origin_x + RANGE
		direction = -1.0
	elif position.x <= origin_x - RANGE:
		position.x = origin_x - RANGE
		direction = 1.0
	_time += delta
	bob = sin(_time * TAU) * BOB
	var next := int(_time * 8.0) % 4
	if next != _frame:
		_frame = next
	queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-SIZE.x / 2.0, -HOVER - SIZE.y / 2.0 + bob), SIZE)


func reset_motion() -> void:
	position.x = origin_x
	direction = 1.0
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
