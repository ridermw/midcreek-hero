extends Control

# A drawn phone screen that shows where each touch control lives during play.
const SIZE := Vector2(720, 260)
const LINE := Color(0.55, 0.6, 0.66)
const TEXT := Color(0.92, 0.96, 0.98)
const ACCENT := Color(0.33, 0.78, 0.95)


func _init() -> void:
	custom_minimum_size = SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	accessibility_name = "Touch controls layout"
	accessibility_description = "Touch the left half of the screen and drag to run or climb. Jump is at the lower right. Slide, Repair and Diagnose appear beside Jump only when needed. The timer and health are at the top left; Full screen and Pause are at the top right."


func _draw() -> void:
	var font := get_theme_default_font()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.025, 0.06, 0.08)
	frame.border_color = LINE
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(18)
	draw_style_box(frame, Rect2(Vector2.ZERO, SIZE))
	draw_rect(Rect2(6, 6, 354, 248), Color(ACCENT, 0.1))
	draw_dashed_line(Vector2(360, 10), Vector2(360, 250), LINE, 2.0, 8.0)
	_pill(font, Rect2(16, 14, 196, 36), "1:23 | Health 5/5", false)
	_text(font, Vector2(114, 72), "Tap for tasks", 16, LINE)
	_text(font, Vector2(180, 108), "Touch and drag anywhere here", 20, TEXT)
	_text(font, Vector2(180, 134), "to run or climb", 20, TEXT)
	draw_arc(Vector2(180, 196), 40, 0, TAU, 48, Color(TEXT, 0.6), 3.0, true)
	draw_circle(Vector2(201, 189), 17, Color(TEXT, 0.75))
	_pill(font, Rect2(462, 14, 128, 36), "Full screen", false)
	_pill(font, Rect2(598, 14, 106, 36), "Pause", false)
	_text(font, Vector2(540, 84), "Slide, Repair and Diagnose", 17, LINE)
	_text(font, Vector2(540, 108), "appear only when needed", 17, LINE)
	_pill(font, Rect2(484, 132, 100, 48), "Slide", true)
	_pill(font, Rect2(484, 190, 100, 48), "Repair", true)
	draw_circle(Vector2(646, 190), 50, Color(ACCENT, 0.25))
	draw_arc(Vector2(646, 190), 50, 0, TAU, 64, ACCENT, 3.0, true)
	_text(font, Vector2(646, 197), "Jump", 20, TEXT)


func _text(font: Font, center: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(font, Vector2(center.x - 160, center.y), text, HORIZONTAL_ALIGNMENT_CENTER, 320, font_size, color)


func _pill(font: Font, rect: Rect2, text: String, dashed: bool) -> void:
	if dashed:
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for i: int in range(4):
			draw_dashed_line(corners[i], corners[(i + 1) % 4], LINE, 2.0, 6.0)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.35)
		style.border_color = LINE
		style.set_border_width_all(2)
		style.set_corner_radius_all(int(rect.size.y / 2))
		draw_style_box(style, rect)
	_text(font, rect.get_center() + Vector2(0, 6), text, 17, TEXT)
