extends Node2D

const REPAIR_SECONDS := 2.0
const INTERACTION_RANGE := 76.0
const FAULT_COLOR := Color(0.88, 0.20, 0.17, 1.0)
const ONLINE_COLOR := Color(0.16, 0.68, 0.39, 1.0)
const HIGHLIGHT_COLOR := Color(0.96, 0.72, 0.13, 1.0)

var repaired: bool = false
var highlighted: bool = false
var progress: float = 0.0
var status_color: Color = FAULT_COLOR

@onready var status_label: Label = $Status


func is_in_range(hero_position: Vector2) -> bool:
	return (
		absf(hero_position.x - global_position.x) <= INTERACTION_RANGE
		and absf(hero_position.y - global_position.y) < 12.0
	)


func set_highlight(value: bool) -> void:
	if highlighted != value:
		highlighted = value
		queue_redraw()


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func finish_repair() -> void:
	repaired = true
	progress = 1.0
	status_color = ONLINE_COLOR
	status_label.text = "R12 / ONLINE"
	status_label.add_theme_color_override("font_color", ONLINE_COLOR)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-49, -161, 98, 18), Color(0.07, 0.12, 0.16, 0.94))
	draw_rect(Rect2(22, -130, 5, 9), status_color)
	if highlighted:
		for corner: Vector2 in [
			Vector2(-30, -134),
			Vector2(30, -134),
			Vector2(-30, -16),
			Vector2(30, -16),
		]:
			var horizontal := 8.0 if corner.x < 0.0 else -8.0
			var vertical := 8.0 if corner.y < -75.0 else -8.0
			draw_line(corner, corner + Vector2(horizontal, 0), HIGHLIGHT_COLOR, 2.0)
			draw_line(corner, corner + Vector2(0, vertical), HIGHLIGHT_COLOR, 2.0)
	if progress > 0.0:
		draw_rect(Rect2(-28, -10, 56, 3), Color(0.12, 0.18, 0.22, 1.0))
		draw_rect(Rect2(-28, -10, roundf(56.0 * progress), 3), status_color)
