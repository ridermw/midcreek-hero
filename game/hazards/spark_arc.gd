extends Node2D

signal sparked

const OFF_SECONDS := 1.4
const WARNING_SECONDS := 0.5
const ON_SECONDS := 0.6
const CYCLE := OFF_SECONDS + WARNING_SECONDS + ON_SECONDS
const SIZE := Vector2(64, 24)

var cell_x: int = 0:
	set(value):
		cell_x = value
		offset = fmod(value * 0.53, CYCLE)
		_update_state()
var offset: float = 0.0
var state: String = "off"
var active: bool = false
var art: RefCounted
var _time: float = 0.0
var _frame: int = -1
var _started: bool = false


func advance(delta: float) -> void:
	if not _started:
		_started = true
		if active:
			sparked.emit()
	_time += delta
	_update_state()
	var frame := int(_time * 12.0) % 4
	if frame != _frame:
		_frame = frame
		queue_redraw()


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-SIZE.x / 2.0, -28), SIZE)


func _update_state() -> void:
	var local := fmod(_time + offset, CYCLE)
	var next := "on"
	if local < OFF_SECONDS:
		next = "off"
	elif local < OFF_SECONDS + WARNING_SECONDS:
		next = "warning"
	active = next == "on"
	if next != state:
		state = next
		queue_redraw()
		if active and _started:
			sparked.emit()


func _draw() -> void:
	var has_art: bool = art != null and art.has("hazards", "spark-arc") and art.has("tiles", "spark-emitter")
	if has_art:
		draw_texture(art.texture("tiles", "spark-emitter"), Vector2(-48, -32))
		draw_texture(art.texture("tiles", "spark-emitter"), Vector2(16, -32))
	else:
		draw_rect(Rect2(-44, -24, 10, 24), Color(0.4, 0.4, 0.35))
		draw_rect(Rect2(34, -24, 10, 24), Color(0.4, 0.4, 0.35))
	var flicker := state == "warning" and _frame % 2 == 0
	if state == "on" or flicker:
		var tint := Color.WHITE if state == "on" else Color(1, 1, 1, 0.35)
		if has_art:
			draw_texture(art.texture("hazards", "spark-arc", maxi(_frame, 0)), Vector2(-32, -28), tint)
		else:
			draw_rect(Rect2(-32, -28, 64, 24), Color(0.5, 0.8, 1.0, tint.a * 0.8))
