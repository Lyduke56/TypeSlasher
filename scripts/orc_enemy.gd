extends Node2D

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")

@export var speed: float = 50.0  # Movement speed towards target

@onready var word: RichTextLabel = $Word
@onready var prompt = $Word
@onready var prompt_text = prompt.text

# Target tracking
var target_position: Vector2
var has_target: bool = false

# Targeting state - prevents retyping once word is completed
var is_being_targeted: bool = false

func _ready() -> void:
	pass  # Word will be set by the game manager via set_prompt()
	
func _process(delta: float) -> void: 
	pass

# --- Set word from spawner ---
func set_prompt(new_word: String) -> void:
	word.text = new_word  # keep a clean text for reference
	word.parse_bbcode(new_word)  # start with plain text

func get_prompt() -> String:
	return word.text

# --- Set target position (where to move towards) ---
func set_target_position(target: Vector2) -> void:
	target_position = target
	has_target = true
	print("Enemy target set to: ", target)

func set_next_character(next_character_index: int):
	# Don't update visual feedback if enemy is being targeted
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
	word.parse_bbcode(typed_part + next_char_part + remaining_part)

func get_bbcode_color_tag(color: Color) -> String:
	return "[color=#" + color.to_html(false) + "]"

func get_bbcode_end_color_tag() -> String:
	return "[/color]"

func set_targeted_state(targeted: bool):
	"""Called when enemy becomes targeted - slows movement"""
	is_being_targeted = targeted
	if targeted:
		# Change color or add visual effect to show it's targeted
		modulate = Color.GRAY  # Darken the enemy
	else:
		modulate = Color.WHITE  # Reset color

func _physics_process(delta: float) -> void:
	if has_target and not is_being_targeted:
		# Move towards target position only if not being targeted
		var direction = (target_position - global_position).normalized()
		global_position += direction * speed * delta
		
		# Optional: Stop when close enough to target
		if global_position.distance_to(target_position) < 5.0:
			has_target = false  # Stop moving when reached
	elif not has_target and not is_being_targeted:
		# Fallback: move downward like before if no target and not being targeted
		global_position.y += speed * delta
