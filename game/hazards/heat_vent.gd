extends Node2D

const OFF_SECONDS := 1.5
const WARNING_SECONDS := 0.4
const ON_SECONDS := 1.0
const CYCLE := OFF_SECONDS + WARNING_SECONDS + ON_SECONDS
const PLUME_SIZE := Vector2(28, 64)

var cell_x: int = 0:
	set(value):
		cell_x = value
		offset = fmod(value * 0.37, CYCLE)
		_update_state()
var offset: float = 0.0
var state: String = "off"
var active: bool = false
var enabled: bool = true
var art: RefCounted
var _time: float = 0.0
var _frame: int = -1


func advance(delta: float) -> void:
	_time += delta
	_update_state()
	var frame := int(_time * 8.0) % 4
	if frame != _frame:
		_frame = frame
		queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-PLUME_SIZE.x / 2.0, -PLUME_SIZE.y), PLUME_SIZE)


func _update_state() -> void:
	var local := fmod(_time + offset, CYCLE)
	var next := "on"
	if local < OFF_SECONDS:
		next = "off"
	elif local < OFF_SECONDS + WARNING_SECONDS:
		next = "warning"
	if not enabled:
		next = "off"
	if next != state:
		state = next
		queue_redraw()
	active = state == "on"


func set_enabled(value: bool) -> void:
	enabled = value
	_update_state()


func reset_motion() -> void:
	_time = 0.0
	_frame = 0
	_update_state()
	queue_redraw()


func _draw() -> void:
	var frame := maxi(_frame, 0)
	if art != null and art.has("hazards", "heat-vent") and art.has("hazards", "heat-plume"):
		if state != "off":
			var plume: Texture2D = art.texture("hazards", "heat-plume", frame)
			var tint := Color(1, 1, 1, 0.45) if state == "warning" else Color.WHITE
			draw_texture(plume, Vector2(-16, -64), tint)
		draw_texture(art.texture("hazards", "heat-vent", frame if state != "off" else 0), Vector2(-16, -16))
		return
	draw_rect(Rect2(-14, -6, 28, 6), Color(0.35, 0.3, 0.3))
	if state != "off":
		var alpha := 0.35 if state == "warning" else 0.8
		draw_rect(Rect2(-PLUME_SIZE.x / 2.0, -PLUME_SIZE.y, PLUME_SIZE.x, PLUME_SIZE.y), Color(1.0, 0.45, 0.1, alpha))
