extends SceneTree

const Health = preload("res://game/health.gd")
const SlaTimer = preload("res://game/sla_timer.gd")
const TaskSystem = preload("res://game/task_system.gd")
const Hud = preload("res://game/hud.gd")
const SpriteLibrary = preload("res://game/sprite_library.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var hud := Hud.new()
	var art := SpriteLibrary.new()
	art.load_group("ui")
	hud.art = art
	root.add_child(hud)
	var health := Health.new()
	var timer := SlaTimer.new()
	var tasks := TaskSystem.new()
	tasks.add_task("r1", "repair", true)
	tasks.add_task("f1", "fetch", false, "Fix")
	timer.start(125.0)
	hud.bind(health, timer, tasks)
	check(hud.health_shown() == 5, "HUD shows 5 full segments.")
	health.damage()
	check(hud.health_shown() == 4, "HUD follows damage.")
	check(hud.segments[4].texture == art.texture("ui", "health-empty"), "Empty segments use the empty icon.")
	check(hud.timer_label.text == "SLA 02:05", "Timer shows minutes and seconds.")
	check(Hud.format_time(29.2) == "SLA 00:30", "format_time rounds up.")
	check(hud.get_node("Panel") is ColorRect, "A dark panel sits behind the HUD text.")
	var expected: Array[String] = ["[ ] Repair rack R1", "[ ] Fix (optional)"]
	check(hud.task_lines() == expected, "Task list shows open tasks.")
	tasks.complete("r1")
	check(hud.task_lines()[0] == "[x] Repair rack R1", "Task list marks done tasks.")
	check(hud.task_icon(0) == art.texture("ui", "task-done"), "Done tasks show the done icon.")
	check(hud.task_list.get_child(0).get_child(1).text == "Repair rack R1", "Labels do not repeat the checkbox.")
	hud.show_stars(3)
	var before := hud.get_child_count()
	hud.show_stars(2)
	check(hud.get_child_count() == before, "show_stars reuses one row.")
	check(hud.star_icons.size() == 3 and hud.star_icons[1].texture == art.texture("ui", "star-on") and hud.star_icons[2].texture == art.texture("ui", "star-off"), "Results show earned stars.")
	timer.tick(100.0)
	hud.update_timer()
	var shown := hud.timer_label.modulate
	check(Color(shown.r, shown.g, shown.b) == Hud.WARNING_COLOR, "Timer turns red at 30 s or less.")
	hud.show_message("Stars: 3")
	check(hud.message_label.visible and hud.message_label.text == "Stars: 3", "show_message shows text.")
	for i: int in range(3):
		tasks.add_task("extra%d" % i, "repair", true)
	hud.refresh_tasks()
	hud.set_carry("Carrying PSU")
	await process_frame
	await process_frame
	check(
		hud.carry_label.get_global_rect().position.y >= hud.task_list.get_global_rect().end.y,
		"The carried part label stays below all five work orders.",
	)
	check(
		(hud.get_node("Panel") as Control).get_global_rect().encloses(hud.carry_label.get_global_rect()),
		"The HUD panel covers the carried part label below five work orders.",
	)
	hud.queue_free()
	await process_frame
	print("HUD_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
