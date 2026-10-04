extends CharacterBody2D

const PlayerMotor = preload("res://game/player_motor.gd")
const BODY_SIZE := Vector2(18, 48)

var motor := PlayerMotor.new()
var use_override: bool = false
var input_override: Dictionary = {}
var locked: bool = false
var action: StringName = &""


func read_input() -> Dictionary:
	if use_override:
		var current := input_override.duplicate()
		input_override.erase("jump_pressed")
		return current
	return {
		"direction": Input.get_axis(&"move_left", &"move_right"),
		"jump_pressed": Input.is_action_just_pressed(&"jump"),
		"jump_held": Input.is_action_pressed(&"jump"),
	}


func _physics_process(delta: float) -> void:
	var input := {} if locked else read_input()
	velocity = motor.step(input, is_on_floor(), delta)
	move_and_slide()
	motor.velocity = velocity


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-BODY_SIZE.x / 2.0, -BODY_SIZE.y), BODY_SIZE)


func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	motor.reset()
