extends Node2D

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")

@export var speed: float = 50.0  # Movement speed towards target
@export var can_split: bool = true  # Can this slime spawn children when killed?
@export var split_count: int = 2    # Number of children to spawn when splitting
@export var word_category: String = "medium"  # Difficulty category for slime words
@onready var anim = $AnimatedSprite2D
@onready var word: RichTextLabel = $Word
@onready var prompt = $Word
@onready var prompt_text = prompt.text
@onready var area: Area2D = $Area2D

# Target tracking
var target_position: Vector2
var has_target: bool = false

# Targeting state - prevents retyping once word is completed
var is_being_targeted: bool = false

# Collision state
var has_reached_target: bool = false
var hack_timer: Timer
# Reference to target node for taking damage
var target_node: Node2D

var points_for_kill = 100

func _ready() -> void:
	# Connect collision signal
	area.body_entered.connect(_on_body_entered)
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
			anim.play("slime_idle")
		modulate = Color.GRAY  # Darken the enemy
	else:
		modulate = Color.WHITE  # Reset color

func play_death_animation():
	"""Play damage animation followed by death animation"""
	if not anim:
		queue_free()  # Fallback if no animation
		return

	# Prevent multiple animations on the same enemy
	if anim.animation == "slime_death" or anim.animation == "slime_damaged":
		return

	# Disconnect any existing connections to prevent duplicates
	if anim.animation_finished.is_connected(_on_damage_animation_finished):
		anim.animation_finished.disconnect(_on_damage_animation_finished)

	# Connect the signal and play damage animation first
	anim.animation_finished.connect(_on_damage_animation_finished, CONNECT_ONE_SHOT)
	anim.play("slime_damaged")

	print("Enemy damage animation started")

func _on_damage_animation_finished():
	"""Called when damage animation completes - plays death animation"""
	if anim.animation == "slime_damaged":
		# Disconnect any existing connections to prevent duplicates
		if anim.animation_finished.is_connected(_on_death_animation_finished):
			anim.animation_finished.disconnect(_on_death_animation_finished)

		# Connect the signal and play death animation
		anim.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
		anim.play("slime_death")

		print("Enemy death animation started")

func _on_death_animation_finished():
	"""Called when death animation completes"""
	if anim.animation == "slime_death":
		Global.current_score += points_for_kill
		# Check for Sword buff health restoration
		Global.on_enemy_killed()

		# Split into smaller slimes if allowed - spawn BEFORE queue_free for proper positioning
		if can_split and split_count > 0:
			var death_position = global_position  # Store death position BEFORE queue_free
			print("Parent slime dying at position: ", death_position)
			spawn_split_slimes(death_position)
			# Delay death to show split effect
			await get_tree().create_timer(0.3).timeout

		queue_free()  # Remove enemy from scene

func spawn_split_slimes(death_position: Vector2):
	"""Spawn smaller slimes at death location"""
	var parent_container = get_parent()  # Get enemy container
	print("Spawning ", split_count, " child slimes around position: ", death_position)

	for i in range(split_count):
		# Create new slime instance
		var child_slime = load("res://Scenes/Enemies/basic_slime.tscn").instantiate()

		# Position with slight offset to prevent stacking - convert global to local coordinates
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		child_slime.position = parent_container.to_local(death_position) + offset
		print("Child slime ", i + 1, " spawning at: ", child_slime.global_position, " (local position: ", child_slime.position, ")")

		# Make child slime non-splitting (one-time only)
		child_slime.can_split = false
		child_slime.speed = speed  # Same speed but will be modified in _ready

		# Set target (same as parent)
		child_slime.set_target_position(target_position)

		# Give child slime easier word (defer to ensure proper initialization)
		call_deferred("_setup_child_prompt", child_slime)

		# Add to scene
		parent_container.add_child(child_slime)

	print("Slime split into ", split_count, " children at death location!")

func _setup_child_prompt(child_slime: Node2D):
	"""Deferred setup of child slime prompt to ensure proper initialization"""
	# Give child slime easier word
	var child_word = _get_unique_word("easy")  # Easy difficulty for children
	child_slime.set_prompt(child_word)
	child_slime.word_category = "easy"
	print("Child slime spawned with word: '", child_word, "' (easy difficulty)")

func _get_unique_word(new_category: String = "") -> String:
	"""Get a unique word for the enemy"""
	var category_to_use = new_category if new_category != "" else word_category

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

func _on_body_entered(body: Node2D):
	"""Called when enemy collides with something"""
	# Check if collided with target (target has StaticBody2D)
	if body is StaticBody2D and body.get_parent().name == "Target":
		if not has_reached_target:
			has_reached_target = true
			target_node = body.get_parent()  # Store reference to target for damage
			has_target = false  # Stop normal movement
			print("Enemy reached target! Starting hack timer and playing idle.")

			# Play idle animation immediately
			if anim:
				anim.play("slime_idle")

			# Create and start timer for 1.5 second intervals
			hack_timer = Timer.new()
			add_child(hack_timer)
			hack_timer.wait_time = 1.5
			hack_timer.one_shot = false  # Repeat indefinitely
			hack_timer.timeout.connect(_on_hack_timer_timeout)
			hack_timer.start()

func _on_hack_timer_timeout():
	"""Called every 1.5 seconds to play attack animation"""
	if has_reached_target and not is_being_targeted and anim:
		# Temporarily disable looping for attack animation so it plays once
		anim.sprite_frames.set_animation_loop("slime_attack", false)
		anim.play("slime_attack")
		print("Enemy attacking the target!")

func _on_animation_finished():
	"""Called when any animation finishes"""
	# Don't interfere with death/damage animations or when enemy is being targeted
	if anim and (anim.animation == "slime_death" or anim.animation == "slime_damaged" or is_being_targeted):
		return

	if has_reached_target and anim and anim.animation == "slime_attack":
		# Attack animation finished, go back to idle and take damage
		anim.play("slime_idle")
		print("Enemy finished attacking, back to idle.")
		if target_node:
			target_node.take_damage()

func _physics_process(delta: float) -> void:
	# STOP ALL MOVEMENT if being targeted or has reached target
	if is_being_targeted or has_reached_target:
		# Don't override death/damage animations
		if anim and (anim.animation == "slime_death" or anim.animation == "slime_damaged"):
			return  # Let death/damage animations play

		# When reached target and not being targeted, play idle only if not currently attacking
		if anim and has_reached_target and not is_being_targeted and anim.animation != "slime_attack":
			anim.play("slime_idle")
		return  # Exit function completely - no movement at all

	# Only move if NOT being targeted and hasn't reached target
	if has_target:
		# Move towards target position
		var direction = (target_position - global_position).normalized()

		if anim:
			anim.play("slime_run")
			anim.flip_h = direction.x < 0

		global_position += direction * speed * delta

		# Stop when close enough to target
		if global_position.distance_to(target_position) < 5.0:
			has_target = false
			if anim:
				anim.play("slime_idle")
	else:
		# Fallback: move downward if no specific target
		if anim:
			anim.play("slime_idle")
		global_position.y += speed * delta
