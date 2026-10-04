extends Node2D

const SIZE := Vector2(28, 10)
const RANGE := 96.0
const SPEED := 60.0

var active: bool = true
var art: RefCounted
var origin_x: float = 0.0
var direction: float = 1.0
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
	var next := int(_time * 8.0) % 4
	if next != _frame:
		_frame = next
		queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-SIZE.x / 2.0, -SIZE.y), SIZE)


func _draw() -> void:
	if art != null and art.has("hazards", "moving-snag"):
		draw_texture(art.texture("hazards", "moving-snag", maxi(_frame, 0)), Vector2(-16, -16))
		return
	draw_rect(Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y), Color(0.95, 0.4, 0.1))
