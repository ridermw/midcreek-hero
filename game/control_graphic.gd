extends Label

var pulse := false
var held := false
var reduced_motion := false
var _clock := 0.0


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(64, 44)
	add_theme_font_size_override("font_size", 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if OS.has_feature("web"):
		reduced_motion = bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches"))


func show_model(model: Dictionary) -> void:
	var graphic: Dictionary = model.get("graphic", {})
	visible = not graphic.is_empty()
	if not visible:
		return
	text = graphic["label"]
	pulse = bool(model.get("pulse", false))
	held = bool(model.get("held", false))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.17, 0.22)
	style.border_color = Color(0.77, 0.94, 0.43)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22 if graphic["shape"] == "button" else 6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	add_theme_stylebox_override("normal", style)


func _process(delta: float) -> void:
	_clock += delta
	modulate.a = 0.78 + 0.22 * (0.5 + 0.5 * cos(_clock * TAU / 2.4)) if pulse and not held and not reduced_motion else 1.0
