extends Area2D

@export var speed: float = 100.0

@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var target: Node2D
var character: String

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	character = char(randi_range(97, 122)) # Random lowercase letter
	label.text = character

func set_target(new_target: Node2D) -> void:
	target = new_target

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	var direction = (target.global_position - global_position).normalized()
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var player = body
		if player.has_method("take_damage"):
			player.take_damage()
		queue_free()

func get_prompt() -> String:
	return character

func play_death_animation():
	queue_free()
