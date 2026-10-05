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
		if int(file.substr(0, 2)) <= 5:
			check(equipment.scale == Vector2.ONE, file + " original foreground racks retain their authored scale.")
		else:
			check(equipment.texture.get_size() == Vector2(320, 180) and equipment.scale == Vector2(2, 2), file + " compact foreground keeps a 640 by 360 world footprint.")
		level.queue_free()
		await process_frame
	var fixture := "user://expansion-background.level"
	var file := FileAccess.open(fixture, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string("res://levels/01-cold-aisle.level").replace('"cold-aisle"', '"cooling-gallery"'))
	file.close()
	var expansion := LEVEL_SCENE.instantiate()
	expansion.level_path = fixture
	root.add_child(expansion)
	check(expansion.error_message.is_empty(), "A new environment loads through its ordered manifest.")
	if expansion.error_message.is_empty():
		var equipment := expansion.get_node("World/Equipment").get_child(0) as Sprite2D
		check(equipment.texture.get_size() == Vector2(320, 180) and equipment.scale == Vector2(2, 2), "Compact art retains the intended world size.")
	expansion.queue_free()
	await process_frame
	DirAccess.remove_absolute(fixture)
	print("BACKGROUND_COVERAGE_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
