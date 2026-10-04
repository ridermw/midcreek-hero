extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	var splash: String = ProjectSettings.get_setting("application/boot_splash/image", "")
	check(not splash.is_empty(), "Startup uses game artwork instead of the engine logo.")
	if not splash.is_empty():
		var texture := load(splash) as Texture2D
		check(texture != null, "The startup brand is an imported texture.")
		if texture != null:
			check(texture.get_width() >= 480 and texture.get_height() >= 120, "The brand fits the title artwork without a tiny icon.")
	check(ProjectSettings.get_setting("application/boot_splash/show_image", true), "Startup displays the game brand.")
	var color: Color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.WHITE)
	check(color.get_luminance() < 0.1, "Startup uses a dark backdrop that makes the game brand readable.")
	check(not ProjectSettings.get_setting("application/boot_splash/use_filter", true), "Startup preserves the pixel artwork.")
	var icon_path: String = ProjectSettings.get_setting("application/config/icon", "")
	check(not icon_path.is_empty(), "The app has its own tab and home screen icon.")
	if not icon_path.is_empty():
		var icon := load(icon_path) as Texture2D
		check(icon != null and icon.get_width() == icon.get_height(), "The app icon is square without distorting the logo.")
	print("BRANDING_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
