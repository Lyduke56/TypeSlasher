extends Node2D

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")

@export var attack_interval: float = 1.25  # Time between arrow shots
@export var boss_health: int = 5  # Boss health, requires 5 hits to defeat
@export var word_category: String = "sentence"  # Category for boss words
@onready var anim = $AnimatedSprite2D
@onready var word: RichTextLabel = $Word
@onready var prompt = $Word
@onready var prompt_text = prompt.text
@onready var heart_container = $"Node2D/HeartContainer"

# Boss health system
var max_boss_health: int = 5
var death_started: bool = false

# Movement pattern system
enum MovementState { IDLE, MOVING_LEFT, WAITING_LEFT, MOVING_CENTER, WAITING_CENTER, MOVING_RIGHT, WAITING_RIGHT }
var current_movement_state: MovementState = MovementState.IDLE
var movement_timer: Timer
@export var move_speed: float = 50.0  # Pixels per second
var left_target: Vector2
var right_target: Vector2
var center_position: Vector2
@export var move_duration: float = 5.0  # 5 seconds to reach targets
@export var wait_duration: float = 5.0  # 5 seconds waiting at each position

# Target tracking - archer stays in place
var target_position: Vector2
var has_target: bool = false

# Targeting state - prevents retyping once word is completed
var is_being_targeted: bool = false

# Attack state
var attack_timer: Timer
var can_attack: bool = true

# Targeting phases
var attacks_since_last_targetable: int = 0
var attacks_required_for_targetable: int = 8  # 15-20 attacks, using 18 as middle
var is_targetable: bool = false
var targetable_timer: Timer
var targetable_duration: float = 10.0  # 10 seconds targetable

@export var points_for_kill = 150

# Signals
signal targetable_phase_ended  # Emitted when targetable phase ends (timer or damage)

# Room reference for word coordination
var associated_room: Node2D = null

func _ready() -> void:
	# Initialize boss health
	boss_health = max_boss_health

	# Archer stays in place and attacks with arrows
	anim.play("tentaclussy_idle")

	# Setup attack timer
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = attack_interval
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	attack_timer.start()

	# Setup health UI
	setup_boss_health_ui()

	# Initialize movement pattern
	setup_movement_pattern()

	# Initially hide the word since boss starts untargetable
	if word:
		word.visible = false

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
	# Only allow targeting if the boss is in targetable phase
	if targeted and not is_targetable:
		return

	is_being_targeted = targeted
	if targeted:
		# Stop moving and play idle animation when targeted
		if anim:
			anim.play("tentaclussy_idle")
		modulate = Color.GRAY  # Darken the enemy
	else:
		modulate = Color.WHITE  # Reset color

func take_damage(attacker_global_position: Vector2 = global_position):
	"""Boss takes damage from player, requires 5 hits to defeat"""
	# Allow lethal damage even if already dead
	if boss_health <= 0:
		return

	boss_health -= 1
	update_boss_health_ui()

	print("Tentaclussy boss damaged! Health: ", boss_health, "/", max_boss_health)

	# If dead now, play death immediately
	if boss_health <= 0:
		play_death_animation()
		return

	# If boss was targetable, immediately end targetable phase after taking damage
	if is_targetable:
		become_untargetable()

	# Note: Boss word remains stable during targetable phases
	# _refresh_word() is not called here to prevent word changes during targeting

func play_death_animation():
	"""Play death animation immediately and clean up on finish"""
	# Stop any attack loop
	if attack_timer:
		attack_timer.stop()
		attack_timer.queue_free()
		attack_timer = null
	can_attack = false

	if not anim:
		queue_free()
		return

	# Prevent multiple death plays
	if death_started or anim.animation == "tentaclussy_death":
		return

	# Only play death if boss health is 0
	if boss_health > 0:
		print("Boss cannot die yet, health remaining: ", boss_health)
		return

	death_started = true

	# Ensure we only listen once for death end
	if anim.animation_finished.is_connected(_on_death_animation_finished):
		anim.animation_finished.disconnect(_on_death_animation_finished)
	if anim.animation_finished.is_connected(_on_damage_animation_finished):
		anim.animation_finished.disconnect(_on_damage_animation_finished)
	anim.animation_finished.connect(_on_death_animation_finished)
	anim.play("tentaclussy_death")
	print("Tentaclussy death animation started")

func _on_damage_animation_finished():
	"""Called when damage animation completes - plays death animation"""
	if anim.animation == "tentaclussy_damaged":
		# Disconnect any existing connections to prevent duplicates
		if anim.animation_finished.is_connected(_on_death_animation_finished):
			anim.animation_finished.disconnect(_on_death_animation_finished)

		# Connect the signal and play death animation
		anim.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
		anim.play("tentaclussy_death")

		print("Enemy death animation started")

func _on_death_animation_finished():
	"""Called when death animation completes"""
	if anim.animation == "tentaclussy_death":
		Global.current_score += points_for_kill
		# Check for Sword buff health restoration
		Global.on_enemy_killed()
		queue_free()  # Remove enemy from scene

func setup_boss_health_ui():
	"""Setup the health UI for the boss"""
	if heart_container:
		# Clear any existing hearts
		for child in heart_container.get_children():
			if child is Panel:
				child.queue_free()

		# Add the correct number of hearts
		for i in range(max_boss_health):
			var heart_scene: PackedScene = preload("res://Scenes/GUI/HeartGUI.tscn")
			var heart = heart_scene.instantiate()
			if heart and heart is Panel:
				heart_container.add_child(heart)
				# Initially all hearts are visible (full health)
				heart.visible = true

func update_boss_health_ui():
	"""Update the health UI to show remaining boss hearts"""
	if heart_container:
		var heart_count = heart_container.get_child_count()
		for i in range(heart_count):
			var heart = heart_container.get_child(i)
			if heart and heart is Panel:
				# Show heart if boss still has health remaining
				heart.visible = (i < boss_health)
		print("Boss health UI updated: ", boss_health, " hearts remaining")

func setup_movement_pattern():
	"""Initialize the movement pattern with left/right/center positions"""
	# Set center position (starting position)
	center_position = global_position

	# Calculate left and right targets based on distance
	# Move 200 pixels left and right from center
	var move_distance = 200.0
	left_target = center_position + Vector2(-move_distance, 0)
	right_target = center_position + Vector2(move_distance, 0)

	# Alternative: Use specific spawn points if they exist
	var room = get_parent()
	if room and room.has_method("get_node_or_null"):
		var left_point = room.get_node_or_null("../LeftPoint")
		var right_point = room.get_node_or_null("../RightPoint")

		if left_point:
			left_target = left_point.global_position
		if right_point:
			right_target = right_point.global_position

	# Setup movement timer
	movement_timer = Timer.new()
	add_child(movement_timer)
	movement_timer.one_shot = true
	movement_timer.timeout.connect(_on_movement_timer_timeout)

	# Setup targetable timer
	targetable_timer = Timer.new()
	add_child(targetable_timer)
	targetable_timer.one_shot = true
	targetable_timer.timeout.connect(_on_targetable_timer_timeout)

	# Start the movement pattern
	start_movement_pattern()

func start_movement_pattern():
	"""Begin the movement pattern cycle"""
	current_movement_state = MovementState.MOVING_LEFT
	print("Tentaclussy starting movement pattern - moving left")

func become_targetable():
	"""Make the boss targetable for 10 seconds - stops all movement"""
	if is_targetable:
		return

	is_targetable = true
	attacks_since_last_targetable = 0  # Reset counter

	# Stop movement timers to prevent state transitions
	if movement_timer and movement_timer.is_inside_tree():
		movement_timer.stop()

	# Play targetable animation (loops for 10 seconds)
	if anim:
		anim.play("tentaclussy_targettable")

	# Set a proper word and show it
	var new_word = _get_unique_word(word_category)
	set_prompt(new_word)
	if word:
		word.visible = true

	# Start the targetable timer
	targetable_timer.wait_time = targetable_duration
	targetable_timer.start()

	print("Tentaclussy became TARGETABLE for 10 seconds - movement stopped!")

func become_untargetable():
	"""Make the boss untargetable again - resumes movement"""
	if not is_targetable:
		return

	is_targetable = false

	# Emit signal IMMEDIATELY to notify dungeon manager that targetable phase ended
	targetable_phase_ended.emit()

	# Clear the word and hide it
	set_prompt("")
	if word:
		word.visible = false

	# Stop being targeted if currently targeted
	if is_being_targeted:
		set_targeted_state(false)

	# Immediately switch to appropriate animation (don't wait for animation to finish)
	if anim:
		var is_moving = (current_movement_state == MovementState.MOVING_LEFT or
						current_movement_state == MovementState.MOVING_CENTER or
						current_movement_state == MovementState.MOVING_RIGHT)

		if is_moving:
			anim.play("tentaclussy_run")
		else:
			anim.play("tentaclussy_idle")

	# Resume movement pattern from current waiting position
	# The movement will continue from the next state in the cycle
	_on_movement_timer_timeout()

	print("Tentaclussy became UNTARGETABLE again - movement resumed")

func _on_targetable_timer_timeout():
	"""Called when targetable time expires"""
	print("Tentaclussy targetable timer expired - clearing word and resuming movement")
	become_untargetable()

func _on_movement_timer_timeout():
	"""Handle movement state transitions"""
	match current_movement_state:
		MovementState.MOVING_LEFT:
			current_movement_state = MovementState.WAITING_LEFT
			# Check if we should become targetable when arriving at waiting position
			if attacks_since_last_targetable >= attacks_required_for_targetable:
				become_targetable()
			else:
				movement_timer.wait_time = wait_duration
				movement_timer.start()
			print("Tentaclussy reached left position - waiting")
		MovementState.WAITING_LEFT:
			current_movement_state = MovementState.MOVING_CENTER
			print("Tentaclussy finished waiting at left - moving to center")
		MovementState.MOVING_CENTER:
			current_movement_state = MovementState.WAITING_CENTER
			# Check if we should become targetable when arriving at waiting position
			if attacks_since_last_targetable >= attacks_required_for_targetable:
				become_targetable()
			else:
				movement_timer.wait_time = wait_duration
				movement_timer.start()
			print("Tentaclussy reached center - waiting")
		MovementState.WAITING_CENTER:
			current_movement_state = MovementState.MOVING_RIGHT
			print("Tentaclussy finished waiting at center - moving right")
		MovementState.MOVING_RIGHT:
			current_movement_state = MovementState.WAITING_RIGHT
			# Check if we should become targetable when arriving at waiting position
			if attacks_since_last_targetable >= attacks_required_for_targetable:
				become_targetable()
			else:
				movement_timer.wait_time = wait_duration
				movement_timer.start()
			print("Tentaclussy reached right position - waiting")
		MovementState.WAITING_RIGHT:
			current_movement_state = MovementState.MOVING_LEFT
			print("Tentaclussy finished waiting at right - starting cycle again")

func _refresh_word():
	# Pull a fresh word and update the prompt
	if typeof(WordDatabase) != TYPE_NIL:
		var new_word = WordDatabase.get_random_word(word_category)
		if new_word != "":
			set_prompt(new_word)

func _on_attack_timer_timeout():
	"""Called periodically to shoot arrows"""
	if not is_being_targeted and can_attack and not is_targetable:
		shoot_arrow()

func shoot_arrow():
	"""Instantiate and shoot an arrow toward the target - similar to slime spawning children"""
	if not has_target:
		return

	# Increment attack counter
	attacks_since_last_targetable += 1

	# Play appropriate attack animation based on movement state
	if anim:
		var is_moving = (current_movement_state == MovementState.MOVING_LEFT or
						current_movement_state == MovementState.MOVING_CENTER or
						current_movement_state == MovementState.MOVING_RIGHT)

		var attack_anim = "tentaclussy_front_attack" if not is_moving else "tentaclussy_side_attack"
		anim.play(attack_anim)

	# Get the parent container (same as slime spawning)
	var parent_container = get_parent()  # Usually EnemyContainer

	# Create arrow instance
	var arrow_scene = load("res://Scenes/Boss/fireball.tscn")
	var arrow = arrow_scene.instantiate()

	# Position arrow in front of archer using local coordinates (like slime children)
	var arrow_offset = Vector2(20, -10)  # Adjust based on archer facing
	if anim and anim.flip_h:
		arrow_offset.x = -20  # Flip for left-facing

	# Convert global position to local coordinates relative to parent container
	arrow.position = parent_container.to_local(global_position) + arrow_offset

	# Set arrow target to the same target as archer
	arrow.set_target_position(target_position)

	# Pass room reference to arrow for coordinated word selection
	if associated_room:
		arrow.associated_room = associated_room

	# Set a random word for the arrow (deferred like slime children)
	call_deferred("_setup_arrow_prompt", arrow)

	# Add arrow to the same parent container as the archer
	parent_container.add_child(arrow)

	print("Skeleton archer shot an arrow at position: ", arrow.global_position)

func _setup_arrow_prompt(arrow: Node2D):
	"""Deferred setup of arrow prompt to ensure proper initialization"""
	# Give arrow an easy word - use room's tracked system if available
	var arrow_word: String

	if associated_room and associated_room.has_method("_get_unique_word_for_category"):
		# Use room's tracked word selection - room handles the print
		arrow_word = associated_room._get_unique_word_for_category("easy")
		if arrow_word == "":
			# Room exhausted - use fallback
			arrow_word = _get_unique_word("easy")
			print("Arrow spawned with fallback word: '", arrow_word, "' (easy difficulty - fallback)")
	else:
		# No coordination - use untracked random word
		arrow_word = _get_unique_word("easy")
		print("Arrow spawned with untracked word: '", arrow_word, "' (easy difficulty - untracked)")

	arrow.set_prompt(arrow_word)

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
	if anim and (anim.animation == "tentaclussy_death" or anim.animation == "tentaclussy_damaged" or is_being_targeted):
		return

	# Handle targetable animation - during targetable phase, keep playing targettable animation
	if anim and anim.animation == "tentaclussy_targettable" and is_targetable:
		# Stay in targettable animation during targetable phase
		anim.play("tentaclussy_targettable")
		return

	# Handle targetable animation - when targetable phase ends, go to idle
	if anim and anim.animation == "tentaclussy_targettable" and not is_targetable:
		anim.play("tentaclussy_idle")
		return

	# Return to appropriate animation after attack animations
	if anim and (anim.animation == "tentaclussy_front_attack" or anim.animation == "tentaclussy_side_attack"):
		# Check if we're currently moving or waiting
		var is_moving = (current_movement_state == MovementState.MOVING_LEFT or
						current_movement_state == MovementState.MOVING_CENTER or
						current_movement_state == MovementState.MOVING_RIGHT)

		if is_moving:
			anim.play("tentaclussy_run")
		else:
			anim.play("tentaclussy_idle")

func _physics_process(delta: float) -> void:
	# Handle movement pattern
	if death_started or is_being_targeted or is_targetable:
		return

	var target_pos: Vector2
	var should_move = false

	match current_movement_state:
		MovementState.MOVING_LEFT:
			target_pos = left_target
			should_move = true
		MovementState.MOVING_CENTER:
			target_pos = center_position
			should_move = true
		MovementState.MOVING_RIGHT:
			target_pos = right_target
			should_move = true
		MovementState.WAITING_LEFT, MovementState.WAITING_CENTER, MovementState.WAITING_RIGHT:
			# Not moving during wait states - check if we should become targetable
			if attacks_since_last_targetable >= attacks_required_for_targetable and not is_targetable:
				# Become targetable - this will play animation and show word
				become_targetable()
			else:
				# Play idle animation (don't override attack animations or targetable)
				if anim and anim.animation != "tentaclussy_idle" and anim.animation != "tentaclussy_side_attack" and anim.animation != "tentaclussy_front_attack" and anim.animation != "tentaclussy_targettable":
					anim.play("tentaclussy_idle")
			should_move = false
		MovementState.IDLE:
			should_move = false

	if should_move:
		# Play run animation when moving (don't override attack animations or targetable)
		if anim and anim.animation != "tentaclussy_run" and anim.animation != "tentaclussy_side_attack" and anim.animation != "tentaclussy_front_attack" and anim.animation != "tentaclussy_targettable":
			anim.play("tentaclussy_run")

		# Calculate direction and distance to target
		var direction = (target_pos - global_position).normalized()
		var distance = global_position.distance_to(target_pos)

		# Move towards target
		var move_amount = move_speed * delta
		if move_amount >= distance:
			# Reached target
			global_position = target_pos
			_on_movement_timer_timeout()  # Trigger state transition
		else:
			# Move towards target
			global_position += direction * move_amount

		# Update sprite facing direction (tentaclussy_run faces right by default)
		if anim and direction.x != 0:
			anim.flip_h = direction.x < 0
