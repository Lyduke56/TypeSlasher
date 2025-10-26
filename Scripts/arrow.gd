extends Area2D

@export var speed: float = 25.0

@onready var label: RichTextLabel = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var target: Node2D
var word: String
var is_being_targeted: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("enemy")

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
		print("Arrow hit player, player.is_dashing: ", player.is_dashing, ", player.is_attacking: ", player.is_attacking)
		if not (player.is_dashing or player.is_attacking) and player.has_method("take_damage"):
			player.take_damage()
		queue_free()

func get_prompt() -> String:
	return word

func set_prompt(new_word: String) -> void:
	word = new_word
	label.text = new_word

func play_death_animation():
	queue_free()

func set_targeted_state(targeted: bool):
	is_being_targeted = targeted
	if targeted:
		modulate = Color.GRAY
	else:
		modulate = Color.WHITE

func set_next_character(next_character_index: int):
	var full_text: String = get_prompt()
	var typed_part = ""
	var next_char_part = ""
	var remaining_part = ""

	if next_character_index > 0:
		typed_part = "[color=green]" + full_text.substr(0, next_character_index) + "[/color]"

	if next_character_index >= 0 and next_character_index < full_text.length():
		next_char_part = "[color=blue]" + full_text.substr(next_character_index, 1) + "[/color]"

	if next_character_index + 1 < full_text.length():
		remaining_part = full_text.substr(next_character_index + 1)

	label.text = typed_part + next_char_part + remaining_part
