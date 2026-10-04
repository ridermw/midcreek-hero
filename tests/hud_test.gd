extends SceneTree

const Health = preload("res://game/health.gd")
const SlaTimer = preload("res://game/sla_timer.gd")
const TaskSystem = preload("res://game/task_system.gd")
const Hud = preload("res://game/hud.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var hud := Hud.new()
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
	check(hud.timer_label.text == "SLA 02:05", "Timer shows minutes and seconds.")
	check(Hud.format_time(29.2) == "SLA 00:30", "format_time rounds up.")
	var expected: Array[String] = ["[ ] Repair rack R1", "[ ] Fix (optional)"]
	check(hud.task_lines() == expected, "Task list shows open tasks.")
	tasks.complete("r1")
	check(hud.task_lines()[0] == "[x] Repair rack R1", "Task list marks done tasks.")
	timer.tick(100.0)
	hud.update_timer()
	check(hud.timer_label.modulate == Hud.WARNING_COLOR, "Timer turns red at 30 s or less.")
	hud.show_message("Stars: 3")
	check(hud.message_label.visible and hud.message_label.text == "Stars: 3", "show_message shows text.")
	hud.queue_free()
	await process_frame
	print("HUD_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
