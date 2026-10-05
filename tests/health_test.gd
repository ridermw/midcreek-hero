extends SceneTree

const Health = preload("res://game/health.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var health := Health.new()
	var deaths := [0]
	health.died.connect(func() -> void: deaths[0] += 1)
	check(health.segments == 5, "Health starts with 5 segments.")
	check(health.damage(), "First hit lands.")
	check(health.segments == 4, "A hit removes 1 segment.")
	check(not health.damage(), "A hit during invulnerability is ignored.")
	check(health.segments == 4, "Invulnerability keeps segments.")
	health.tick(0.99)
	check(health.is_invulnerable(), "Invulnerability lasts 1.0 s.")
	health.tick(0.02)
	check(not health.is_invulnerable(), "Invulnerability ends after 1.0 s.")
	health.heal()
	check(health.segments == 5, "Heal restores 1 segment.")
	health.heal()
	check(health.segments == 5, "Heal does not exceed 5 segments.")
	for i: int in range(5):
		health.damage()
		health.tick(1.0)
	check(health.segments == 0, "5 hits empty the bar.")
	check(deaths[0] == 1, "died emits once at 0 segments.")
	check(not health.damage(), "No damage after death.")
	health.heal()
	check(health.segments == 0, "Heal does nothing after death.")
	check(health.hits_taken == 6, "hits_taken counts every landed hit.")
	health.refill()
	check(health.segments == 5 and not health.is_invulnerable(), "refill restores full health.")
	check(health.hits_taken == 6, "refill keeps hits_taken for the star score.")
	check(health.has_method("fatal_damage"), "Fatal liquid has a separate damage path.")
	if health.has_method("fatal_damage"):
		for protected: bool in [false, true]:
			var victim := Health.new()
			var fatal_deaths := [0]
			var values: Array[int] = []
			victim.died.connect(func() -> void: fatal_deaths[0] += 1)
			victim.changed.connect(func(value: int) -> void: values.append(value))
			if protected:
				victim.damage()
				check(victim.is_invulnerable(), "The fatal contact fixture is protected by ordinary invulnerability.")
			var prior_hits := victim.hits_taken
			check(victim.fatal_damage(), "Fatal contact lands regardless of ordinary invulnerability.")
			check(victim.segments == 0 and values.back() == 0, "Fatal contact immediately empties health and updates listeners.")
			check(victim.hits_taken == prior_hits + 1 and fatal_deaths[0] == 1, "One fatal contact records one hit and one death.")
			check(not victim.fatal_damage() and not victim.damage(), "Overlapping contacts do not repeat damage after death.")
			victim.heal()
			check(victim.segments == 0 and fatal_deaths[0] == 1, "Healing cannot cancel fatal contact.")
			victim.refill()
			check(victim.segments == 5 and victim.damage(), "Checkpoint recovery restores ordinary damage behavior.")
	print("HEALTH_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
