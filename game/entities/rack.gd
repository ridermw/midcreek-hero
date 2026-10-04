extends Node2D

const REPAIR_SECONDS := 2.0
const RANGE_X := 40.0
const SIZE := Vector2(40, 96)

var task_id: String = ""
var done: bool = false
var progress: float = 0.0
var art: RefCounted


func in_range(feet: Vector2) -> bool:
	return absf(feet.x - position.x) <= RANGE_X and absf(feet.y - position.y) <= 16.0


func work(delta: float) -> bool:
	if done:
		return false
	progress = minf(progress + delta / REPAIR_SECONDS, 1.0)
	if progress >= 1.0:
		done = true
	queue_redraw()
	return done


func cancel() -> void:
	if not done and progress > 0.0:
		progress = 0.0
		queue_redraw()


func set_done(value: bool) -> void:
	done = value
	progress = 1.0 if value else 0.0
	queue_redraw()


func _draw() -> void:
	if art != null:
		draw_texture(art.texture("tiles", "rack-ok" if done else "rack-fault"), Vector2(-16, -96))
	else:
		draw_rect(Rect2(-SIZE.x / 2.0, -SIZE.y, SIZE.x, SIZE.y), Color(0.18, 0.21, 0.25))
		draw_rect(Rect2(10, -86, 6, 6), Color(0.16, 0.68, 0.39) if done else Color(0.88, 0.2, 0.17))
	if progress > 0.0 and not done:
		draw_rect(Rect2(-20, -104, 40.0 * progress, 4), Color(0.96, 0.72, 0.13))
