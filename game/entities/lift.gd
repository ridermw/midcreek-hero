extends AnimatableBody2D

const RISE := 96.0
const SPEED := 48.0
const PAUSE := 0.5
const TRAVEL := RISE / SPEED
const PERIOD := 2.0 * (PAUSE + TRAVEL)
const SIZE := Vector2(64, 16)

var art: RefCounted
var base_y: float = 0.0
var _time: float = 0.0


static func offset_at(time: float) -> float:
	var t := fmod(time, PERIOD)
	if t < PAUSE:
		return 0.0
	t -= PAUSE
	if t < TRAVEL:
		return t * SPEED
	t -= TRAVEL
	if t < PAUSE:
		return RISE
	t -= PAUSE
	return RISE - t * SPEED


func _ready() -> void:
	base_y = position.y
	collision_layer = 1
	sync_to_physics = true
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = SIZE
	shape.shape = box
	shape.position = Vector2(0, SIZE.y / 2.0)
	shape.one_way_collision = true
	add_child(shape)


func _physics_process(delta: float) -> void:
	_time += delta
	position.y = base_y - offset_at(_time)


func _draw() -> void:
	if art != null and art.has("tiles", "lift"):
		draw_texture(art.texture("tiles", "lift"), Vector2(-32, 0))
	else:
		draw_rect(Rect2(-32, 0, 64, 16), Color(0.85, 0.7, 0.15))
