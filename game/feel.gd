extends RefCounted

const SHAKE_PIXELS := 4.0
const SHAKE_SECONDS := 0.25
const HIT_STOP_SECONDS := 0.05
const PULSE_BELOW := 30.0


static func shake_amplitude(elapsed: float) -> float:
	return maxf(0.0, SHAKE_PIXELS * (1.0 - elapsed / SHAKE_SECONDS))


static func shake_offset(elapsed: float, rng: RandomNumberGenerator) -> Vector2:
	var amplitude := shake_amplitude(elapsed)
	return Vector2(rng.randf_range(-amplitude, amplitude), rng.randf_range(-amplitude, amplitude)).round()


static func timer_pulse(remaining: float, time: float) -> float:
	if remaining > PULSE_BELOW:
		return 1.0
	return 0.6 + 0.4 * absf(cos(time * PI * 2.0))


static func spark_burst(at: Vector2) -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.position = at
	sparks.one_shot = true
	sparks.amount = 18
	sparks.lifetime = 0.45
	sparks.explosiveness = 0.95
	sparks.direction = Vector2(0, -1)
	sparks.spread = 70.0
	sparks.gravity = Vector2(0, 600)
	sparks.initial_velocity_min = 80.0
	sparks.initial_velocity_max = 180.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 3.0
	sparks.color = Color(1.0, 0.85, 0.3)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
	return sparks
