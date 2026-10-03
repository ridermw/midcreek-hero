extends CharacterBody2D

const HeroAnimations = preload("res://game/animation_library.gd")
const WALK_SPEED := 60.0
const RUN_SPEED := 110.0
const MIN_X := 10.0
const MAX_X := 2550.0
const GRAVITY := 900.0
const ACTIONS: Array[StringName] = [&"primary", &"secondary", &"reaction", &"signal"]

@export_enum("man", "woman") var character: String = "man"

var active: bool = false
var action: StringName = &""
var sustained_primary: bool = false
var motion_direction: float = 0.0
var running: bool = false
var _action_remaining: float = 0.0
var _library: HeroAnimations

@onready var visuals: Node2D = $Visuals
@onready var sprite: AnimatedSprite2D = $Visuals/Sprite
@onready var marker: Polygon2D = $Visuals/ActiveMarker


func _ready() -> void:
	set_physics_process(false)
	sprite.animation_finished.connect(_on_animation_finished)


func configure(library: HeroAnimations) -> void:
	_library = library
	sprite.sprite_frames = _library.variants[variant_name()]
	reset_state()
	set_physics_process(true)


func variant_name() -> StringName:
	return StringName(character + "-midcreek")


func set_active(value: bool) -> void:
	active = value
	marker.visible = active
	reset_state()


func reset_state() -> void:
	motion_direction = 0.0
	running = false
	velocity = Vector2.ZERO
	cancel_action()


func set_motion(direction: float, run: bool) -> void:
	motion_direction = clampf(direction, -1.0, 1.0) if active else 0.0
	running = run and active
	if motion_direction != 0.0:
		cancel_action()


func start_action(clip: StringName, sustain: bool = false) -> void:
	if not active:
		return
	if clip not in ACTIONS:
		push_error("Unknown hero action: " + String(clip))
		return
	motion_direction = 0.0
	running = false
	velocity.x = 0.0
	action = clip
	sustained_primary = sustain and clip == &"primary"
	_action_remaining = clip_duration(clip) + 0.15
	sprite.play(clip)
	sprite.set_frame_and_progress(0, 0.0)


func cancel_action() -> void:
	action = &""
	sustained_primary = false
	_action_remaining = 0.0
	_play_locomotion()


func clip_duration(clip: StringName) -> float:
	var frames := sprite.sprite_frames
	return float(frames.get_frame_count(clip)) / frames.get_animation_speed(clip)


func _physics_process(delta: float) -> void:
	if not action.is_empty() and not sustained_primary:
		_action_remaining -= delta
		if _action_remaining <= 0.0:
			cancel_action()
	if action.is_empty():
		velocity.x = motion_direction * (RUN_SPEED if running else WALK_SPEED)
		if velocity.x != 0.0:
			sprite.flip_h = velocity.x < 0.0
		_play_locomotion()
	else:
		velocity.x = 0.0
	velocity.y += GRAVITY * delta
	move_and_slide()
	position.x = clampf(position.x, MIN_X, MAX_X)
	# Keep physical subpixels for accurate speed, but render on whole source pixels.
	visuals.position = global_position.round() - global_position


func _play_locomotion() -> void:
	if _library == null:
		return
	var clip: StringName = &"idle"
	if active and motion_direction != 0.0:
		clip = &"run" if running else &"walk"
	if sprite.animation != clip or not sprite.is_playing():
		sprite.play(clip)


func _on_animation_finished() -> void:
	if action.is_empty():
		return
	if sustained_primary:
		sprite.play(&"primary")
		sprite.set_frame_and_progress(0, 0.0)
	else:
		cancel_action()
