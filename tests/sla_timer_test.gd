extends SceneTree

const SlaTimer = preload("res://game/sla_timer.gd")
const Score = preload("res://game/score.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var timer := SlaTimer.new()
	var counts := {"warning": 0, "expired": 0}
	timer.warning.connect(func() -> void: counts["warning"] += 1)
	timer.expired.connect(func() -> void: counts["expired"] += 1)
	timer.start(100.0)
	check(timer.running and timer.remaining == 100.0, "start sets remaining and runs.")
	timer.tick(69.0)
	check(counts["warning"] == 0, "No warning above 30 s.")
	timer.tick(2.0)
	check(counts["warning"] == 1, "Warning at 30 s or less.")
	timer.tick(1.0)
	check(counts["warning"] == 1, "Warning emits once.")
	timer.tick(40.0)
	check(timer.remaining == 0.0, "remaining stops at 0.")
	check(counts["expired"] == 1, "expired emits at 0.")
	check(not timer.running, "Timer stops at 0.")
	check(timer.elapsed == 100.0, "elapsed counts only time that ran.")
	timer.tick(5.0)
	check(counts["expired"] == 1 and timer.elapsed == 100.0, "A stopped timer does not tick.")
	timer.restore(10.0)
	check(timer.remaining == 30.0 and timer.running, "restore applies the 30 s minimum.")
	timer.tick(5.0)
	check(timer.elapsed == 105.0, "elapsed includes time after a restart.")
	check(counts["warning"] == 1, "No new warning when restored below 30 s.")
	timer.restore(80.0)
	timer.tick(51.0)
	check(counts["warning"] == 2, "restore above 30 s arms the warning again.")
	timer.stop()
	timer.tick(5.0)
	check(timer.remaining == 29.0, "stop pauses the countdown.")
	check(Score.stars(150.0, 150.0, 0) == 1, "Elapsed equal to par gives 1 star.")
	check(Score.stars(149.0, 150.0, 2) == 2, "Under par with 2 hits gives 2 stars.")
	check(Score.stars(149.0, 150.0, 1) == 3, "Under par with 1 hit gives 3 stars.")
	check(Score.stars(10.0, 150.0, 0) == 3, "Under par with 0 hits gives 3 stars.")
	print("SLA_TIMER_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
