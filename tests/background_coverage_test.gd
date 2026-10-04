extends SceneTree

const LEVEL_SCENE := preload("res://game/level.tscn")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	for file: String in DirAccess.get_files_at("res://levels"):
		if not file.ends_with(".level") or file.begins_with("00-"):
			continue
		var level := LEVEL_SCENE.instantiate()
		level.level_path = "res://levels/" + file
		root.add_child(level)
		check(level.error_message.is_empty(), file + " loads.")
		var far := level.get_node("World/Far") as Parallax2D
		var sprite := far.get_child(0) as Sprite2D
		var top := sprite.position.y
		var bottom := top + sprite.texture.get_height() * sprite.scale.y
		check(top <= level.camera.limit_top, file + " distant artwork covers the highest camera view.")
		check(bottom >= level.camera.limit_bottom, file + " distant artwork covers the lowest camera view.")
		check(is_equal_approx(far.repeat_size.x, sprite.texture.get_width() * sprite.scale.x), file + " scaled artwork repeats without horizontal gaps.")
		var equipment := level.get_node("World/Equipment").get_child(0) as Sprite2D
		check(equipment.scale == Vector2.ONE, file + " foreground racks retain their authored scale.")
		level.queue_free()
		await process_frame
	print("BACKGROUND_COVERAGE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
