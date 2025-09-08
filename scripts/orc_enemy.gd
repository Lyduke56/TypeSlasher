extends Node2D

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")

@export var speed: float = 50.0  # Movement speed towards target
@onready var anim = $AnimatedSprite2D
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
	"""Called when enemy becomes targeted - stops movement and plays idle"""
	is_being_targeted = targeted
	if targeted:
		# Stop moving and play idle animation when targeted
		if anim:
			anim.play("idle")
		modulate = Color.GRAY  # Darken the enemy
	else:
		modulate = Color.WHITE  # Reset color

func play_death_animation():
	"""Play death animation and remove enemy after animation completes"""
	if not anim:
		queue_free()  # Fallback if no animation
		return
	
	# Prevent multiple death animations on the same enemy
	if anim.animation == "death":
		return  # Already playing death animation
	
	# Disconnect any existing connections to prevent duplicates
	if anim.animation_finished.is_connected(_on_death_animation_finished):
		anim.animation_finished.disconnect(_on_death_animation_finished)
	
	# Connect the signal and play death animation
	anim.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
	anim.play("death")
	
	print("Enemy death animation started")

func _on_death_animation_finished():
	"""Called when death animation completes"""
	if anim.animation == "death":
		queue_free()  # Remove enemy from scene

func _physics_process(delta: float) -> void:
	# STOP ALL MOVEMENT if being targeted
	if is_being_targeted:
		if anim:
			anim.play("idle")  # Ensure idle animation plays when frozen
		return  # Exit function completely - no movement at all

	# Only move if NOT being targeted
	if has_target:
		# Move towards target position
		var direction = (target_position - global_position).normalized()

		if anim:
			anim.play("running")
			anim.flip_h = direction.x < 0

		global_position += direction * speed * delta

		# Stop when close enough to target
		if global_position.distance_to(target_position) < 5.0:
			has_target = false
			if anim:
				anim.play("idle")
	else:
		# Fallback: move downward if no specific target
		if anim:
			anim.play("idle")
		global_position.y += speed * delta
