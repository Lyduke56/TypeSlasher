extends CharacterBody2D

# Base dash speeds
@export var min_dash_speed: float = 600.0  # Minimum speed for close enemies
@export var max_dash_speed: float = 1500.0  # Maximum speed for far enemies
@export var return_speed: float = 400.0

# Distance thresholds for speed calculation
@export var min_distance: float = 100.0   # Distance at which min_dash_speed is used
@export var max_distance: float = 800.0   # Distance at which max_dash_speed is used

# Animation durations
@export var attack_duration: float = 0.5  # How long the attack animation plays

@onready var anim = $AnimatedSprite2D
@onready var combo_timer: Timer = Timer.new()
@onready var attack_timer: Timer = Timer.new()

var center_position: Vector2
var is_dashing: bool = false
var is_returning: bool = false
var is_attacking: bool = false
var target_position: Vector2
var combo_active: bool = false
var target_enemy = null
var current_dash_speed: float = 600.0  # Will be calculated dynamically
var base_animation_speed: float = 1.0
var fast_animation_speed: float = 5.0  # 3x faster when typing quickly

signal enemy_reached(enemy)
signal slash_completed(target_enemy)

func _ready() -> void:
	# Set center position (you can adjust this based on your scene)
	center_position = Vector2.ZERO
	global_position = center_position

	# Setup combo timer
	add_child(combo_timer)
	combo_timer.wait_time = 3.0
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timeout)

	# Setup attack timer (duration will be set dynamically in _finish_dash)
	add_child(attack_timer)
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_finished)

	# Connect animation finished signal
	anim.animation_finished.connect(_on_animation_finished)

	# Start with idle animation
	anim.play("idle")

func _physics_process(delta: float) -> void:
	if is_dashing or is_returning:
		_handle_movement(delta)

func _handle_movement(delta: float) -> void:
	var current_speed = current_dash_speed if is_dashing else return_speed
	var direction = (target_position - global_position).normalized()

	# Update sprite direction and animation based on movement direction
	_update_directional_animation(direction)

	# Check if we've reached the target
	if global_position.distance_to(target_position) < 10.0:
		global_position = target_position

		if is_dashing:
			_finish_dash()
		elif is_returning:
			_finish_return()
		return

	# Move towards target
	velocity = direction * current_speed
	move_and_slide()

func _update_directional_animation(direction: Vector2) -> void:
	"""Update sprite direction and potentially change animation based on movement direction"""

	# Handle horizontal flipping (always do this)
	if direction.x != 0:
		anim.flip_h = direction.x < 0

func calculate_dash_speed(distance: float) -> float:
	"""Calculate dash speed based on distance to target"""
	# Clamp distance to our min/max range
	var clamped_distance = clamp(distance, min_distance, max_distance)

	# Normalize the distance to a 0-1 range
	var distance_ratio = (clamped_distance - min_distance) / (max_distance - min_distance)

	# Interpolate between min and max speed
	var calculated_speed = lerp(min_dash_speed, max_dash_speed, distance_ratio)

	print("Distance: ", distance, " -> Speed: ", calculated_speed)
	return calculated_speed

func dash_to_enemy(enemy_position: Vector2, enemy_ref = null) -> void:
	if is_returning:
		combo_timer.stop()

	# If we're already attacking, speed up the current animation
	if is_attacking:
		print("Speeding up current slash animation")
		anim.speed_scale = fast_animation_speed

	target_position = enemy_position
	target_enemy = enemy_ref

	# Calculate dynamic dash speed based on distance
	var distance_to_enemy = global_position.distance_to(enemy_position)
	current_dash_speed = calculate_dash_speed(distance_to_enemy)
	is_dashing = true
	is_returning = false
	is_attacking = false
	# Play dash animation
	anim.play("walking")
	print("Player dashing to: ", enemy_position, " at speed: ", current_dash_speed)

func _finish_dash() -> void:
	is_dashing = false
	is_attacking = true
	combo_active = true
	combo_timer.start()

	# Play attack animation
	anim.play("attack")

	# Kill the enemy with a short delay (e.g., 0.3 seconds) regardless of animation
	if target_enemy != null:
		var enemy_to_kill = target_enemy
		target_enemy = null  # Clear reference immediately

		# Create a short timer to kill the enemy
		var kill_timer = Timer.new()
		add_child(kill_timer)
		kill_timer.wait_time = 0.3  # Adjust this delay as needed
		kill_timer.one_shot = true
		kill_timer.timeout.connect(func():
			print("Killing enemy after delay")
			slash_completed.emit(enemy_to_kill)
			kill_timer.queue_free()  # Clean up the timer
		)
		kill_timer.start()

	print("Attack started - enemy will die in 0.3 seconds")
	print("Combo window started - 3 seconds to next target!")

func _on_animation_finished() -> void:
	"""Called when any animation finishes"""
	# Only handle attack animation finishing
	if is_attacking and anim.animation == "attack":
		_on_attack_finished()

func _on_attack_finished() -> void:
	"""Called when attack animation completes"""
	is_attacking = false

	# Reset animation speed to normal
	anim.speed_scale = base_animation_speed

	# Emit signal to destroy the enemy after attack animation finishes
	if target_enemy != null:
		print("Emitting slash_completed signal for: ", target_enemy)
		slash_completed.emit(target_enemy)
		target_enemy = null

	# Return to idle animation
	anim.play("idle")
	print("Attack animation finished - returning to idle")

func _on_combo_timeout() -> void:
	if not is_dashing and not is_attacking:  # Don't return if we're dashing or attacking
		_return_to_center()
	combo_active = false
	print("Combo window expired - returning to center")

func _return_to_center() -> void:
	target_position = center_position
	is_returning = true
	is_dashing = false
	is_attacking = false

	# Play return/run animation (or use dash animation for returning)
	anim.play("walking")  # or "dash" if you want to reuse the dash animation

func _finish_return() -> void:
	is_returning = false

	# Return to idle animation
	anim.play("idle")

	print("Player returned to center")

# Public function to check if player is in combo state
func is_in_combo() -> bool:
	return combo_active

# Function to reset combo (if needed)
func reset_combo() -> void:
	combo_timer.stop()
	attack_timer.stop()
	combo_active = false
	is_attacking = false

	if not is_returning:
		_return_to_center()
