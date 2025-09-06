extends CharacterBody2D


@export var speed: float = 100.0
@onready var anim = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	var input_vector = Vector2.ZERO
	
	# Read movement input
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	input_vector = input_vector.normalized()
	
	# Movement (no gravity needed for top-down)
	velocity = input_vector * speed
	move_and_slide()

	# Animations
