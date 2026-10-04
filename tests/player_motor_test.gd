extends SceneTree

const PlayerMotor = preload("res://game/player_motor.gd")
const LevelValidator = preload("res://game/level_validator.gd")
const DT := 1.0 / 60.0

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func coyote_jump(air_steps: int) -> bool:
	var motor := PlayerMotor.new()
	motor.step({}, true, DT)
	for i: int in range(air_steps):
		motor.step({}, false, DT)
	return motor.step({"jump_pressed": true, "jump_held": true}, false, DT).y == -PlayerMotor.JUMP_VELOCITY


func buffered_jump(air_steps: int) -> bool:
	var motor := PlayerMotor.new()
	motor.step({"jump_pressed": true, "jump_held": true}, false, DT)
	for i: int in range(air_steps):
		motor.step({"jump_held": true}, false, DT)
	return motor.step({"jump_held": true}, true, DT).y == -PlayerMotor.JUMP_VELOCITY


func landing_x(rise_pixels: float) -> float:
	var motor := PlayerMotor.new()
	var position := Vector2.ZERO
	motor.step({}, true, DT)
	var input := {"direction": 1.0, "jump_pressed": true, "jump_held": true}
	for i: int in range(240):
		var velocity := motor.step(input, i == 0, DT)
		input = {"direction": 1.0, "jump_held": true}
		var next := position + velocity * DT
		if velocity.y > 0.0 and position.y <= -rise_pixels and next.y > -rise_pixels:
			return next.x
		position = next
	return 0.0


func run() -> void:
	var motor := PlayerMotor.new()
	var velocity := motor.step({"direction": 1.0}, true, DT)
	check(is_equal_approx(velocity.x, PlayerMotor.ACCELERATION * DT), "Running accelerates.")
	for i: int in range(30):
		velocity = motor.step({"direction": 1.0}, true, DT)
	check(velocity.x == PlayerMotor.RUN_SPEED, "Run speed caps at 180 px/s.")
	check(motor.facing == 1.0, "facing follows direction.")
	velocity = motor.step({"direction": -1.0}, true, DT)
	check(motor.facing == -1.0 and velocity.x < PlayerMotor.RUN_SPEED, "Turning decelerates first.")
	check(coyote_jump(4), "Jump works 5 steps after leaving a ledge.")
	check(not coyote_jump(6), "Jump fails 7 steps after leaving a ledge.")
	check(buffered_jump(4), "A jump pressed 5 steps before landing happens.")
	check(not buffered_jump(6), "A jump pressed 7 steps before landing is dropped.")
	motor.reset()
	motor.step({"jump_pressed": true, "jump_held": true}, true, DT)
	velocity = motor.step({}, false, DT)
	check(velocity.y == -PlayerMotor.JUMP_CUT_VELOCITY, "Releasing jump cuts the rise.")
	motor.reset()
	for i: int in range(120):
		velocity = motor.step({}, false, DT)
	check(velocity.y == PlayerMotor.MAX_FALL_SPEED, "Fall speed caps at 600 px/s.")
	motor.reset()
	check(motor.velocity == Vector2.ZERO, "reset clears velocity.")
	for rise: int in LevelValidator.JUMP_REACH:
		var across: int = LevelValidator.JUMP_REACH[rise]
		check(
			landing_x(rise * 32.0) >= across * 32.0 - 16.0,
			"Motor reaches %d tiles across at %d tiles up." % [across, rise],
		)
	var slider := PlayerMotor.new()
	slider.facing = 1.0
	var slide := slider.step({"slide_pressed": true}, {"on_floor": true}, DT)
	check(slider.sliding and slide.x == PlayerMotor.SLIDE_SPEED, "Slide starts at 260 px/s in the facing direction.")
	for i: int in range(26):
		slide = slider.step({}, {"on_floor": true}, DT)
	check(slider.sliding, "Slide lasts 0.45 s.")
	for i: int in range(2):
		slide = slider.step({}, {"on_floor": true, "ceiling_blocked": true}, DT)
	check(slider.sliding, "Slide continues under a low ceiling.")
	slide = slider.step({}, {"on_floor": true}, DT)
	check(not slider.sliding, "Slide ends when the ceiling clears.")
	var air := PlayerMotor.new()
	check(not air.step({"slide_pressed": true}, {"on_floor": false}, DT).x == PlayerMotor.SLIDE_SPEED and not air.sliding, "Slide needs the floor.")
	var wall := PlayerMotor.new()
	wall.velocity.y = 400.0
	var falling := wall.step({"direction": 1.0}, {"on_wall": true, "wall_normal_x": -1.0}, DT)
	check(falling.y == PlayerMotor.WALL_SLIDE_SPEED, "Pressing into a wall in the air caps the fall at 90 px/s.")
	var kick := wall.step({"direction": 1.0, "jump_pressed": true}, {"on_wall": true, "wall_normal_x": -1.0}, DT)
	check(kick == Vector2(-PlayerMotor.WALL_JUMP_PUSH, -PlayerMotor.WALL_JUMP_VELOCITY), "Wall jump pushes away from the wall.")
	kick = wall.step({"direction": 1.0, "jump_held": true}, {}, DT)
	check(kick.x < 0.0, "Input toward the wall is ignored briefly after a wall jump.")
	var away := PlayerMotor.new()
	away.velocity.y = 400.0
	check(away.step({"direction": -1.0}, {"on_wall": true, "wall_normal_x": -1.0}, DT).y > PlayerMotor.WALL_SLIDE_SPEED, "No wall slide without pressing into the wall.")
	for sample: Dictionary in [
		{"direction": 0.4, "normal": -1.0, "push": -220.0},
		{"direction": -0.4, "normal": 1.0, "push": 220.0},
	]:
		var analog := PlayerMotor.new()
		analog.velocity.y = 400.0
		var context := {"on_wall": true, "wall_normal_x": sample["normal"]}
		var analog_fall := analog.step({"direction": sample["direction"]}, context, DT)
		check(analog_fall.y == 90.0, "Partial stick input toward either wall slows the fall.")
		var analog_kick := analog.step({"direction": sample["direction"], "jump_pressed": true}, context, DT)
		check(analog_kick == Vector2(sample["push"], -460.0), "Partial stick input allows a jump away from either wall.")
	for direction: float in [0.0, -0.4]:
		var released := PlayerMotor.new()
		released.velocity.y = 400.0
		check(released.step({"direction": direction}, {"on_wall": true, "wall_normal_x": -1.0}, DT).y > 90.0, "Neutral or partial input away from a wall does not slow the fall.")
	var edge := PlayerMotor.new()
	edge.step({"direction": 1.0}, {"on_floor": true}, DT)
	var coyote_kick := edge.step({"direction": 1.0, "jump_pressed": true, "jump_held": true}, {"on_wall": true, "wall_normal_x": -1.0}, DT)
	check(coyote_kick.x < 0.0 and edge.facing == -1.0, "A wall jump wins over coyote time at a wall.")
	var locked := PlayerMotor.new()
	locked.velocity.y = 200.0
	locked.step({"direction": 1.0, "jump_pressed": true}, {"on_wall": true, "wall_normal_x": -1.0}, DT)
	locked.step({"vertical": -1.0}, {"on_ladder": true}, DT)
	check(not locked.climbing, "A ladder does not catch the player during the wall jump lock.")
	var climber := PlayerMotor.new()
	var climb := climber.step({"vertical": -1.0}, {"on_ladder": true}, DT)
	check(climber.climbing and climb == Vector2(0, -PlayerMotor.CLIMB_SPEED), "Up on a ladder climbs at 90 px/s.")
	climb = climber.step({}, {"on_ladder": true}, DT)
	check(climb == Vector2.ZERO, "A climber with no input holds still.")
	climb = climber.step({"jump_pressed": true, "jump_held": true}, {"on_ladder": true}, DT)
	check(not climber.climbing and climb.y == -PlayerMotor.JUMP_VELOCITY, "Jump leaves the ladder.")
	climber.step({"vertical": -1.0}, {"on_ladder": true}, DT)
	climb = climber.step({"vertical": -1.0}, {"on_ladder": false}, DT)
	check(not climber.climbing, "Leaving the ladder ends the climb.")
	for direction: float in [-0.4, 0.4]:
		var turning_climber := PlayerMotor.new()
		turning_climber.facing = -signf(direction)
		turning_climber.step({"vertical": -1.0, "direction": direction}, {"on_ladder": true}, DT)
		check(turning_climber.facing == signf(direction), "Entering a ladder faces toward horizontal input.")
		turning_climber.step({"direction": -direction}, {"on_ladder": true}, DT)
		check(turning_climber.facing == -signf(direction), "Reversing sideways movement on a ladder turns the player.")
		turning_climber.step({"vertical": 1.0}, {"on_ladder": true}, DT)
		check(turning_climber.facing == -signf(direction), "Vertical climbing preserves the last horizontal facing.")
		turning_climber.step({}, {"on_ladder": true}, DT)
		check(turning_climber.facing == -signf(direction), "Holding still on a ladder preserves facing.")
		turning_climber.step({"direction": direction, "jump_pressed": true, "jump_held": true}, {"on_ladder": true}, DT)
		check(turning_climber.facing == signf(direction), "Jumping sideways from a ladder faces the launch direction.")
	print("PLAYER_MOTOR_TEST_COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
