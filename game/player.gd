extends CharacterBody2D

signal sound(sound_name: String)

const PlayerMotor = preload("res://game/player_motor.gd")
const HeroAnimations = preload("res://game/animation_library.gd")
const BODY_SIZE := Vector2(18, 64)
const SLIDE_HEIGHT := 24.0
const CEILING_MASK := 4
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
var on_ladder: bool = false
var _shape: RectangleShape2D
var _suppress_landing: bool = true

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision


func _ready() -> void:
	_shape = (collision.shape as RectangleShape2D).duplicate()
	collision.shape = _shape


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
		"vertical": Input.get_axis(&"move_up", &"move_down"),
		"jump_pressed": Input.is_action_just_pressed(&"jump"),
		"jump_held": Input.is_action_pressed(&"jump"),
		"slide_pressed": Input.is_action_just_pressed(&"slide"),
	}


func body_height() -> float:
	return _shape.size.y


func _set_body_height(height: float) -> void:
	if _shape.size.y != height:
		_shape.size = Vector2(BODY_SIZE.x, height)
		collision.position = Vector2(0, -height / 2.0)


func standing_blocked() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var standing := RectangleShape2D.new()
	standing.size = Vector2(BODY_SIZE.x - 2.0, BODY_SIZE.y - 2.0)
	query.shape = standing
	query.transform = Transform2D(0.0, global_position + Vector2(0, -BODY_SIZE.y / 2.0 - 1.0))
	query.collision_mask = CEILING_MASK
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _physics_process(delta: float) -> void:
	var input := {} if locked else read_input()
	var was_on_floor := is_on_floor()
	var context := {
		"on_floor": was_on_floor,
		"on_wall": is_on_wall_only(),
		"wall_normal_x": get_wall_normal().x if is_on_wall() else 0.0,
		"ceiling_blocked": motor.sliding and standing_blocked(),
		"on_ladder": on_ladder,
	}
	velocity = motor.step(input, context, delta)
	sliding = motor.sliding
	_set_body_height(SLIDE_HEIGHT if sliding else BODY_SIZE.y)
	if velocity.y == -PlayerMotor.JUMP_VELOCITY:
		sound.emit("jump")
	move_and_slide()
	if not _suppress_landing and not was_on_floor and is_on_floor():
		sound.emit("land")
	_suppress_landing = false
	motor.velocity = velocity
	hurt_remaining = maxf(hurt_remaining - delta, 0.0)
	update_animation()


func update_animation() -> void:
	sprite.flip_h = motor.facing < 0.0
	if sprite.sprite_frames == null:
		return
	var clip := choose_clip(is_on_floor(), velocity, sliding, hurt_remaining > 0.0, action)
	if motor.climbing and hurt_remaining <= 0.0 and action.is_empty():
		clip = &"walk" if velocity.y != 0.0 else &"idle"
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
	var height := body_height() if _shape != null else BODY_SIZE.y
	return Rect2(position + Vector2(-BODY_SIZE.x / 2.0, -height), Vector2(BODY_SIZE.x, height))


func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	motor.reset()
	hurt_remaining = 0.0
	sliding = false
	if _shape != null:
		_set_body_height(BODY_SIZE.y)
	_suppress_landing = true
