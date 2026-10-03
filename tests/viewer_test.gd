extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var scene := load("res://viewer.tscn") as PackedScene
	var viewer := scene.instantiate()
	root.add_child(viewer)
	await process_frame
	check(viewer.textures.size() == 24, "All 24 sprites load.")
	check(viewer.current_index == 0, "Starts at the first sprite.")
	var seen: Dictionary = {}
	for i: int in range(24):
		var texture: Texture2D = viewer.image.texture
		check(texture != null, "Sprite %d is present." % i)
		check(texture.get_size() == Vector2(208, 208), "Sprite %d has the right size." % i)
		seen[texture.resource_path] = true
		press(viewer, KEY_SPACE, true, true)
		check(viewer.current_index == i, "Key repeat does not advance.")
		press(viewer, KEY_SPACE, false, false)
		check(viewer.current_index == i, "Key release does not advance.")
		press(viewer, KEY_ENTER, true, false)
		check(viewer.current_index == i, "Other keys do not advance.")
		press(viewer, KEY_SPACE, true, false)
		check(viewer.current_index == (i + 1) % 24, "Space advances exactly once.")
	check(seen.size() == 24, "Every sprite is distinct.")
	check(viewer.current_index == 0, "Wraps back to the first sprite.")
	check(viewer.hint.text.begins_with("1 / 24"), "Counter wraps with the image.")
	print("VIEWER_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func press(viewer: Node, key: Key, pressed: bool, echo: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	event.echo = echo
	viewer._unhandled_key_input(event)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
