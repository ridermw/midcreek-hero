extends CharacterBody2D

const PlayerMotor = preload("res://game/player_motor.gd")
const HeroAnimations = preload("res://game/animation_library.gd")
const BODY_SIZE := Vector2(18, 64)
const HURT_SECONDS := 0.4
const RUN_THRESHOLD := 120.0
const WALK_THRESHOLD := 10.0

@export_enum("man", "woman") var character: String = "man"

var motor := PlayerMotor.new()
var use_override: bool = false
var input_override: Dictionary = {}
var locked: bool = false
var action: StringName = &""
var sliding: bool = false
var hurt_remaining: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite


static func choose_clip(
	on_floor: bool, motion: Vector2, is_sliding: bool, is_hurt: bool, current_action: StringName
) -> StringName:
	if is_hurt:
		return &"reaction"
	if not current_action.is_empty():
		return current_action
	if is_sliding:
		return &"slide"
	if not on_floor:
		return &"jump"
	if absf(motion.x) > RUN_THRESHOLD:
		return &"run"
	if absf(motion.x) > WALK_THRESHOLD:
		return &"walk"
	return &"idle"


func configure(library: HeroAnimations) -> void:
	sprite.sprite_frames = library.variants[StringName(character + "-midcreek")]
	sprite.play(&"idle")


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
	hurt_remaining = maxf(hurt_remaining - delta, 0.0)
	update_animation()


func update_animation() -> void:
	sprite.flip_h = motor.facing < 0.0
	if sprite.sprite_frames == null:
		return
	var clip := choose_clip(is_on_floor(), velocity, sliding, hurt_remaining > 0.0, action)
	if sprite.animation != clip:
		sprite.play(clip)
	elif clip == action and not sprite.is_playing():
		sprite.play(clip)
		sprite.set_frame_and_progress(0, 0.0)
	elif clip == &"jump" and sprite.frame == sprite.sprite_frames.get_frame_count(clip) - 1:
		sprite.pause()


func hurt() -> void:
	hurt_remaining = HURT_SECONDS


func hit_rect() -> Rect2:
	return Rect2(position + Vector2(-BODY_SIZE.x / 2.0, -BODY_SIZE.y), BODY_SIZE)


func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	motor.reset()
	hurt_remaining = 0.0
