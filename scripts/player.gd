extends CharacterBody2D

# Base dash speeds
@export var min_dash_speed: float = 600.0  # Minimum speed for close enemies
@export var max_dash_speed: float = 1500.0  # Maximum speed for far enemies
@export var return_speed: float = 400.0

# Distance thresholds for speed calculation
@export var min_distance: float = 100.0   # Distance at which min_dash_speed is used
@export var max_distance: float = 800.0   # Distance at which max_dash_speed is used

@onready var anim = $AnimatedSprite2D
@onready var combo_timer: Timer = Timer.new()

var center_position: Vector2
var is_dashing: bool = false
var is_returning: bool = false
var target_position: Vector2
var combo_active: bool = false
var target_enemy = null
var current_dash_speed: float = 600.0  # Will be calculated dynamically

signal enemy_reached(enemy)

func _ready() -> void:
	# Set center position (you can adjust this based on your scene)
	center_position = Vector2.ZERO
	global_position = center_position
	
	# Setup combo timer
	add_child(combo_timer)
	combo_timer.wait_time = 3.0
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_on_combo_timeout)

func _physics_process(delta: float) -> void:
	if is_dashing or is_returning:
		_handle_movement(delta)

func _handle_movement(delta: float) -> void:
	var current_speed = current_dash_speed if is_dashing else return_speed
	var direction = (target_position - global_position).normalized()
	
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
	
	target_position = enemy_position
	target_enemy = enemy_ref
	
	# Calculate dynamic dash speed based on distance
	var distance_to_enemy = global_position.distance_to(enemy_position)
	current_dash_speed = calculate_dash_speed(distance_to_enemy)
	
	is_dashing = true
	is_returning = false
	
	print("Player dashing to: ", enemy_position, " at speed: ", current_dash_speed)

func _finish_dash() -> void:
	is_dashing = false
	combo_active = true
	combo_timer.start()
	
	# Emit signal that we reached the enemy
	if target_enemy != null:
		enemy_reached.emit(target_enemy)
		target_enemy = null
	
	print("Combo window started - 3 seconds to next target!")

func _on_combo_timeout() -> void:
	if not is_dashing:  # Don't return if we're already dashing to another enemy
		_return_to_center()
	combo_active = false
	print("Combo window expired - returning to center")

func _return_to_center() -> void:
	target_position = center_position
	is_returning = true
	is_dashing = false

func _finish_return() -> void:
	is_returning = false
	print("Player returned to center")

# Public function to check if player is in combo state
func is_in_combo() -> bool:
	return combo_active

# Function to reset combo (if needed)
func reset_combo() -> void:
	combo_timer.stop()
	combo_active = false
	if not is_returning:
		_return_to_center()
