extends Node2D

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")
@onready var sfx_attack: AudioStreamPlayer2D = $sfx_attack
@onready var sfx_death: AudioStreamPlayer2D = $sfx_death
@onready var sfx_damaged: AudioStreamPlayer2D = $sfx_damaged

@export var attack_interval: float = 2.0  # Time between arrow shots
@onready var anim = $AnimatedSprite2D
@onready var word: RichTextLabel = $Word
@onready var area: Area2D = $Area2D

# Target tracking - archer stays in place
var target_position: Vector2
var has_target: bool = false

# Targeting state - prevents retyping once word is completed
var is_being_targeted: bool = false

# Attack state
var attack_timer: Timer
var can_attack: bool = true

@export var points_for_kill = 150

func _ready() -> void:
	# Archer stays in place and attacks with arrows
	anim.play("skeleton_archer_idle")

	# Setup attack timer
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = attack_interval
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

	# Connect animation finished signal
	if anim:
		anim.animation_finished.connect(_on_animation_finished)
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
			anim.play("skeleton_archer_idle")
		modulate = Color.GRAY  # Darken the enemy
	else:
		modulate = Color.WHITE  # Reset color

func play_death_animation():
	"""Play damage animation followed by death animation"""
	if not anim:
		queue_free()  # Fallback if no animation
		return

	# Prevent multiple animations on the same enemy
	if anim.animation == "skeleton_archer_death" or anim.animation == "skeleton_archer_damaged":
		return

	# Disconnect any existing connections to prevent duplicates
	if anim.animation_finished.is_connected(_on_damage_animation_finished):
		anim.animation_finished.disconnect(_on_damage_animation_finished)

	# Connect the signal and play damage animation first
	anim.animation_finished.connect(_on_damage_animation_finished, CONNECT_ONE_SHOT)
	anim.play("skeleton_archer_damaged")
	$sfx_damaged.play()
	print("Enemy damage animation started")

func _on_damage_animation_finished():
	"""Called when damage animation completes - plays death animation"""
	if anim.animation == "skeleton_archer_damaged":
		# Disconnect any existing connections to prevent duplicates
		if anim.animation_finished.is_connected(_on_death_animation_finished):
			anim.animation_finished.disconnect(_on_death_animation_finished)

		# Connect the signal and play death animation
		anim.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
		anim.play("skeleton_archer_death")
		$sfx_death.play()
		print("Enemy death animation started")

func _on_death_animation_finished():
	"""Called when death animation completes"""
	if anim.animation == "skeleton_archer_death":
		Global.current_score += points_for_kill
		# Check for Sword buff health restoration
		Global.on_enemy_killed()
		queue_free()  # Remove enemy from scene

func _on_attack_timer_timeout():
	"""Called periodically to shoot arrows"""
	if not is_being_targeted and can_attack:
		shoot_arrow()

func shoot_arrow():
	"""Instantiate and shoot an arrow toward the target - similar to slime spawning children"""
	if not has_target:
		return

	# Play attack animation
	if anim:
		anim.play("skeleton_archer_attack")
		$sfx_attack.play()
	# Get the parent container (same as slime spawning)
	var parent_container = get_parent()  # Usually EnemyContainer

	# Create arrow instance
	var arrow_scene = load("res://Scenes/Enemies/arrow.tscn")
	var arrow = arrow_scene.instantiate()

	# Position arrow in front of archer using local coordinates (like slime children)
	var arrow_offset = Vector2(20, -10)  # Adjust based on archer facing
	if anim and anim.flip_h:
		arrow_offset.x = -20  # Flip for left-facing

	# Convert global position to local coordinates relative to parent container
	arrow.position = parent_container.to_local(global_position) + arrow_offset

	# Set arrow target to the same target as archer
	arrow.set_target_position(target_position)

	# Set a random word for the arrow (deferred like slime children)
	call_deferred("_setup_arrow_prompt", arrow)

	# Add arrow to the same parent container as the archer
	parent_container.add_child(arrow)

	print("Skeleton archer shot an arrow at position: ", arrow.global_position)

func _setup_arrow_prompt(arrow: Node2D):
	"""Deferred setup of arrow prompt to ensure proper initialization"""
	# Give arrow an easy word (same as slime children)
	var arrow_word = _get_unique_word("easy")  # Use easy words for arrows
	arrow.set_prompt(arrow_word)
	print("Arrow spawned with word: '", arrow_word, "' (easy difficulty)")

func _get_unique_word(new_category: String = "") -> String:
	"""Get a unique word for the enemy (same as slime)"""
	var category_to_use = new_category if new_category != "" else "medium"

	if not WordDatabase:
		print("WordDatabase not loaded!")
		return "enemy"

	var available_words = WordDatabase.get_category_words(category_to_use)
	if available_words.is_empty():
		print("No words available in category: " + category_to_use + ", falling back to medium")
		available_words = WordDatabase.get_category_words("medium")
		if available_words.is_empty():
			return "enemy"

	# Pick random word
	return available_words[randi() % available_words.size()]

func _on_animation_finished():
	"""Called when any animation finishes"""
	# Don't interfere with death/damage animations or when enemy is being targeted
	if anim and (anim.animation == "skeleton_archer_death" or anim.animation == "skeleton_archer_damaged" or is_being_targeted):
		return

	# Return to idle after attack animation
	if anim and anim.animation == "skeleton_archer_attack":
		anim.play("skeleton_archer_idle")

func _physics_process(delta: float) -> void:
	# Archer stays in place - no movement
	pass
