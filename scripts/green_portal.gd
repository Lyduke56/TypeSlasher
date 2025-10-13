extends Node2D

signal portal_selected(portal_index: int)

@onready var animated_sprite = $AnimatedSprite2D
@onready var area_2d = $AnimatedSprite2D/Area2D
@onready var label = $Location

var portal_index: int = 0

# Typing system variables (similar to enemies)
@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
var is_being_targeted: bool = false
var prompt_text: String = ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.body_entered.connect(_on_body_entered)
	var location_names = ["Top", "Left", "Right"]
	prompt_text = location_names[portal_index]
	set_prompt(prompt_text)  # Display location name

# --- Typing interface functions (similar to enemies) ---
func set_prompt(new_word: String) -> void:
	prompt_text = new_word
	label.parse_bbcode(new_word)  # start with plain text

func get_prompt() -> String:
	return prompt_text

func set_next_character(next_character_index: int):
	# Don't update visual feedback if portal is being targeted
	if is_being_targeted:
		return

	# Additional safety check
	if not is_instance_valid(self):
		return

	var full_text: String = get_prompt()

	# Bounds checking
	if next_character_index < -1 or next_character_index > full_text.length():
		print("Warning: Invalid character index: ", next_character_index)
		return

	var typed_part = ""
	var next_char_part = ""
	var remaining_part = ""

	# already typed → green
	if next_character_index > 0:
		typed_part = get_bbcode_color_tag(green) + full_text.substr(0, next_character_index) + get_bbcode_end_color_tag()

	# next character → blue
	if next_character_index >= 0 and next_character_index < full_text.length():
		next_char_part = get_bbcode_color_tag(blue) + full_text.substr(next_character_index, 1) + get_bbcode_end_color_tag()

	# remaining → normal
	if next_character_index + 1 < full_text.length():
		remaining_part = full_text.substr(next_character_index + 1)

	# apply to label
	label.parse_bbcode(typed_part + next_char_part + remaining_part)

func get_bbcode_color_tag(color: Color) -> String:
	return "[color=#" + color.to_html(false) + "]"

func get_bbcode_end_color_tag() -> String:
	return "[/color]"

func set_targeted_state(targeted: bool):
	"""Called when portal becomes targeted"""
	is_being_targeted = targeted
	if targeted:
		modulate = Color.GRAY  # Darken the portal
	else:
		modulate = Color.WHITE  # Reset color

func play_appear_animation():
	animated_sprite.play("appear")
	await animated_sprite.animation_finished
	animated_sprite.play("idle")

func play_disappear_animation():
	animated_sprite.play("disappear")
	await animated_sprite.animation_finished
	queue_free()

# Portal handled by typing completion now - kept for safety
func _on_body_entered(body: Node2D):
	pass  # Typing system handles portal activation now
