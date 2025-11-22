extends CharacterBody2D

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")

@export var boss_health: int = 5  # Boss health, requires 5 hits to defeat
@export var word_category: String = "medium"  # Category for boss words
@export var targetable_word_category: String = "sentence"  # Category for words during targetable phase after knockback
@onready var anim = $AnimatedSprite2D
@onready var word: RichTextLabel = $Word
@onready var prompt = $Word
@onready var prompt_text = prompt.text
@onready var heart_container = $"Node2D/HeartContainer"

# Boss health system
var max_boss_health: int = 5
var death_started: bool = false

# Movement pattern system - Top, Right, Bottom, Left cycle
enum MovementState { IDLE, MOVING_TOP, MOVING_RIGHT, MOVING_BOTTOM, MOVING_LEFT }
var current_movement_state: MovementState = MovementState.IDLE
@export var move_speed: float = 80.0  # Movement speed between nodes
var top_position: Vector2
var right_position: Vector2
var bottom_position: Vector2
var left_position: Vector2
var current_target_position: Vector2

# Attack pattern system
enum AttackState { IDLE, SHOOTING, WAITING, DASHING, ATTACKING }
var current_attack_state: AttackState = AttackState.IDLE
var attack_timer: Timer
var idle_timer: Timer
var hack_timer: Timer  # Like minotaur - continuous attack timer
var fireball_count: int = 0
@export var max_fireballs: int = 1  # 2 fireballs per position (8 total)
@export var idle_duration: float = 3.0  # 3 seconds idle before becoming targetable
@export var fireball_interval: float = 0.3  # Time between fireballs
var positions_completed: int = 0  # Track completed positions
var has_reached_position: bool = false  # Prevent multiple position reach calls
var has_attacked_target: bool = false  # Prevent multiple attack calls
var has_reached_target: bool = false  # Like minotaur - tracks if reached target for continuous attacks

# Target tracking
var target_position: Vector2
var has_target: bool = false

# Targeting state
var is_being_targeted: bool = false
var is_targetable: bool = false  # Only targetable during dash phase

# Reference to target node for taking damage (like minotaur)
var target_node: Node2D

# Knockback system (like Minotaur)
var is_knockbacked: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
@export var knockback_power: float = 500.0
@export var knockback_deceleration: float = 1500.0

# Targetable phase (after knockback)
var targetable_timer: Timer
var targetable_duration: float = 10.0  # 10 seconds targetable after knockback
var is_after_knockback_recovery: bool = false  # True when targetable after knockback recovery

# Room bounds
var room_center: Vector2 = Vector2.ZERO
var room_size: Vector2 = Vector2.ZERO

@export var points_for_kill = 2500

# Signals
signal targetable_phase_ended  # Emitted when targetable phase ends (timer or damage)

func _ready() -> void:
	# Initialize boss health
	boss_health = max_boss_health

	# Start with idle animation
	anim.play("demon_idle")

	# Setup timers
	setup_timers()

	# Setup health UI
	setup_boss_health_ui()

	# Setup room bounds for knockback
	setup_room_bounds()

	# Initially hide the word since boss starts untargetable
	if word:
		word.visible = false

	# Connect animation finished signal
	if anim:
		anim.animation_finished.connect(_on_animation_finished)

	# Start the boss pattern
	start_boss_pattern()

	print("Demon boss initialized - starting at Top position")

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
			anim.play("demon_idle")
		modulate = Color.GRAY  # Darken the enemy
	else:
		modulate = Color.WHITE  # Reset color

func take_damage(attacker_global_position: Vector2 = global_position):
	"""Boss takes damage from player, requires 5 hits to defeat"""
	# Allow lethal damage even if already dead
	if boss_health <= 0:
		return

	# If boss was targetable during attack phase AND after knockback recovery, take damage immediately
	if is_targetable and is_after_knockback_recovery:
		print("Demon boss attacked during targetable phase after knockback - taking damage immediately")
		is_after_knockback_recovery = false  # Reset flag
		boss_health -= 1
		update_boss_health_ui()

		print("Demon boss damaged! Health: ", boss_health, "/", max_boss_health)

		# If dead now, play death immediately
		if boss_health <= 0:
			play_death_animation()
			return

		# Play damaged animation and reset to normal pattern
		if anim:
			anim.play("demon_damaged")
		become_untargetable()
		return

	# If boss was targetable during initial attack phase, perform knockback WITHOUT losing health
	if is_targetable:
		print("Demon boss interrupted during targetable phase - knockback without health loss")
		perform_knockback(attacker_global_position)
		return

	# Only reduce health if NOT targetable (i.e., after knockback recovery)
	boss_health -= 1
	update_boss_health_ui()

	print("Demon boss damaged! Health: ", boss_health, "/", max_boss_health)

	# If dead now, play death immediately
	if boss_health <= 0:
		play_death_animation()
		return

	# Note: Boss word remains stable during targetable phases
	# _refresh_word() is not called here to prevent word changes during targeting

func play_death_animation():
	"""Play death animation immediately and clean up on finish"""
	# Stop any attack loop
	if attack_timer:
		attack_timer.stop()
		attack_timer.queue_free()
		attack_timer = null

	if not anim:
		queue_free()
		return

	# Prevent multiple death plays
	if death_started or anim.animation == "demon_death":
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
	anim.play("demon_death")
	print("Tentaclussy death animation started")

func _on_damage_animation_finished():
	"""Called when damage animation completes - plays death animation"""
	if anim.animation == "demon_damaged":
		# Disconnect any existing connections to prevent duplicates
		if anim.animation_finished.is_connected(_on_death_animation_finished):
			anim.animation_finished.disconnect(_on_death_animation_finished)

		# Connect the signal and play death animation
		anim.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
		anim.play("demon_death")

		print("Enemy death animation started")

func _on_death_animation_finished():
	"""Called when death animation completes"""
	if anim.animation == "demon_death":
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

func setup_timers():
	"""Setup all timers for the demon boss"""
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_fireball_timer_timeout)

	idle_timer = Timer.new()
	add_child(idle_timer)
	idle_timer.one_shot = true
	idle_timer.timeout.connect(_on_idle_timer_timeout)

	targetable_timer = Timer.new()
	add_child(targetable_timer)
	targetable_timer.one_shot = true
	targetable_timer.timeout.connect(_on_targetable_timer_timeout)

func setup_room_bounds():
	"""Setup room bounds for knockback clamping"""
	# Cache room bounds from CameraArea if available
	var room: Node = null
	if get_parent() != null and get_parent().get_parent() != null:
		room = get_parent().get_parent()
	if room != null and room.has_node("CameraArea"):
		var camera_area: Area2D = room.get_node("CameraArea")
		var cs: CollisionShape2D = camera_area.get_node_or_null("CollisionShape2D")
		if cs and cs.shape is RectangleShape2D:
			var shape: RectangleShape2D = cs.shape
			room_size = shape.extents * 2.0
			room_center = camera_area.global_position

func start_boss_pattern():
	"""Start the demon boss pattern - begin at Top position"""
	# Find the Top node position
	find_node_positions()

	# Start at Top position
	global_position = top_position
	current_movement_state = MovementState.IDLE  # At Top, not moving yet
	current_attack_state = AttackState.SHOOTING
	positions_completed = 0

	# Start shooting fireballs immediately at Top
	start_shooting_fireballs()

	print("Demon boss pattern started - at Top, shooting fireballs")

func find_node_positions():
	"""Find the positions of Top, Right, Bottom, Left nodes in BossRoomSpawn/SpawnLocations"""
	var room = get_parent()  # EnemyContainer
	if room and room.has_method("get_node_or_null"):
		# Look for nodes in BossRoomSpawn/SpawnLocations
		var spawn_locations = room.get_node_or_null("../BossRoomSpawn/SpawnLocations")
		if spawn_locations:
			var top_node = spawn_locations.get_node_or_null("Top")
			var right_node = spawn_locations.get_node_or_null("Right")
			var bottom_node = spawn_locations.get_node_or_null("Bottom")
			var left_node = spawn_locations.get_node_or_null("Left")

			if top_node:
				top_position = top_node.global_position
			if right_node:
				right_position = right_node.global_position
			if bottom_node:
				bottom_position = bottom_node.global_position
			if left_node:
				left_position = left_node.global_position

			print("Found node positions in BossRoomSpawn/SpawnLocations - Top:", top_position, " Right:", right_position, " Bottom:", bottom_position, " Left:", left_position)
		else:
			print("ERROR: BossRoomSpawn/SpawnLocations not found!")



func start_shooting_fireballs():
	"""Start shooting fireballs at current position"""
	fireball_count = 0
	current_attack_state = AttackState.SHOOTING

	# Start shooting fireballs
	attack_timer.wait_time = fireball_interval
	attack_timer.start()

	print("Demon boss started shooting fireballs at position")

func _on_fireball_timer_timeout():
	"""Shoot individual fireballs"""
	if current_attack_state != AttackState.SHOOTING:
		return

	fireball_count += 1

	# Play attack animation
	if anim:
		anim.play("demon_attack")

	# Shoot fireball
	shoot_fireball()

	# Check if we've shot enough fireballs
	if fireball_count >= max_fireballs:
		attack_timer.stop()
		start_idle_phase()

func shoot_fireball():
	"""Shoot a single fireball toward the target, spawning around the boss"""
	if not has_target:
		# Try to find Target as target if no target set
		var target = get_tree().root.find_child("Target", true, false)
		if target:
			set_target_position(target.global_position)
		else:
			return

	# Get the parent container
	var parent_container = get_parent()  # Usually EnemyContainer

	# Create fireball instance
	var fireball_scene = load("res://Scenes/Boss/fireballs.tscn")
	var fireball = fireball_scene.instantiate()

	# Spawn fireball around the boss position (not at exact position)
	var random_angle = randf() * 2 * PI  # Random angle in radians (0 to 2π)
	var random_distance = randf_range(15, 35)  # Random distance from boss (15-35 units)

	# Calculate offset from boss center
	var offset_x = cos(random_angle) * random_distance
	var offset_y = sin(random_angle) * random_distance
	var fireball_offset = Vector2(offset_x, offset_y)

	# Convert global position to local coordinates
	fireball.position = parent_container.to_local(global_position) + fireball_offset

	# Set fireball target (ensure it's targeting the correct position)
	fireball.set_target_position(target_position)

	# Set a random word for the fireball
	call_deferred("_setup_fireball_prompt", fireball)

	# Add fireball to the container
	parent_container.add_child(fireball)

	print("Demon boss shot fireball", fireball_count, "/", max_fireballs, " at offset:", fireball_offset)

func _setup_fireball_prompt(fireball: Node2D):
	"""Setup prompt for fireball"""
	var fireball_word = _get_unique_word("easy")
	fireball.set_prompt(fireball_word)
	print("Fireball spawned with word: '", fireball_word, "'")

func start_idle_phase():
	"""Start the idle phase after shooting fireballs at a position"""
	positions_completed += 1

	if positions_completed < 4:
		# Move to next position
		advance_to_next_position()
		current_attack_state = AttackState.SHOOTING
		has_reached_position = false  # Reset flag for next movement
		if anim:
			anim.play("demon_run")
		print("Demon boss completed shooting at position ", positions_completed, ", moving to next position")
	else:
		# All positions completed, do the final idle
		current_attack_state = AttackState.WAITING
		if anim:
			anim.play("demon_idle")
		idle_timer.wait_time = idle_duration
		idle_timer.start()
		print("Demon boss completed all positions, entering final idle phase for ", idle_duration, " seconds")

func _on_idle_timer_timeout():
	"""Called when idle phase ends - start dash phase"""
	if current_attack_state != AttackState.WAITING:
		return

	start_dash_phase()

func start_dash_phase():
	"""Start the dash phase - become targetable and move to target like minotaur"""
	current_attack_state = AttackState.DASHING
	is_targetable = true
	has_reached_target = false  # Reset for new approach

	# Face right during dash phase
	if anim:
		anim.flip_h = true  # true = face right (flip left-facing sprite to face right)

	# Set word and show it
	var dash_word = _get_unique_word(word_category)
	set_prompt(dash_word)
	if word:
		word.visible = true

	# Start targetable timer - if not defeated within time limit, become untargetable
	targetable_timer.wait_time = targetable_duration
	targetable_timer.start()

	print("Demon boss became TARGETABLE and is moving to attack!")

func perform_knockback(attacker_position: Vector2):
	"""Perform knockback when interrupted during dash (like Minotaur)"""
	if not is_targetable:
		return

	is_knockbacked = true
	is_targetable = false  # No longer targetable during knockback

	# Stop any ongoing attack cycle on the target
	if hack_timer:
		hack_timer.stop()
		hack_timer.queue_free()
		hack_timer = null
	# Force re-approach after knockback
	has_reached_target = false
	has_target = false
	set_targeted_state(false)

	# Calculate knockback direction (away from attacker)
	var knockback_direction = (global_position - attacker_position).normalized()

	# If this would knock toward target, invert
	if target_position != Vector2.ZERO:
		var to_target = (target_position - global_position).normalized()
		if knockback_direction.dot(to_target) > 0.0:
			knockback_direction = -knockback_direction

	knockback_velocity = knockback_direction * knockback_power

	# Play damage animation
	if anim:
		anim.play("demon_damaged")

	print("Demon boss knocked back - will become targetable after recovery")

func start_targetable_phase():
	"""Start the targetable phase after knockback recovery"""
	is_targetable = true
	is_after_knockback_recovery = true  # Mark that this is after knockback recovery

	# Stop any ongoing attack movement
	current_attack_state = AttackState.IDLE

	# Set word and show it
	var targetable_word = _get_unique_word(targetable_word_category)
	set_prompt(targetable_word)
	if word:
		word.visible = true

	# Play targetable animation
	if anim:
		anim.play("demon_targettable")

	# Start targetable timer
	targetable_timer.wait_time = targetable_duration
	targetable_timer.start()

	print("Demon boss became TARGETABLE for", targetable_duration, "seconds after knockback")

func _on_targetable_timer_timeout():
	"""Called when targetable phase ends - boss takes damage for failed interruption"""
	print("Demon boss targetable timer expired - boss takes damage and resets to normal pattern")

	# Boss takes damage for failing to be interrupted within time limit
	boss_health -= 1
	update_boss_health_ui()

	print("Demon boss damaged by timeout! Health: ", boss_health, "/", max_boss_health)

	# If dead now, play death immediately
	if boss_health <= 0:
		play_death_animation()
		return

	# Play damaged animation
	if anim:
		anim.play("demon_damaged")

	become_untargetable()

func become_untargetable():
	"""Reset to normal attack pattern"""
	is_targetable = false

	# Stop the targetable timer if it's still running
	if targetable_timer and targetable_timer.is_stopped() == false:
		targetable_timer.stop()

	# Emit signal to reset typing state
	targetable_phase_ended.emit()

	# Clear word
	set_prompt("")
	if word:
		word.visible = false

	# Stop being targeted
	if is_being_targeted:
		set_targeted_state(false)

	# Reset attack state and start moving to next position
	reset_to_normal_pattern()

func reset_to_normal_pattern():
	"""Reset to normal movement and attack pattern"""
	current_attack_state = AttackState.SHOOTING

	# Reset the movement cycle
	positions_completed = 0
	has_reached_position = false
	has_attacked_target = false

	# Move to Top position using movement system (no teleport)
	current_movement_state = MovementState.MOVING_TOP
	current_target_position = top_position

	print("Demon boss reset to normal pattern - moving to Top position")

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
	if anim and (anim.animation == "demon_death" or anim.animation == "demon_damaged" or is_being_targeted):
		return

	# Handle targetable animation - during targetable phase, keep playing targettable animation
	if anim and anim.animation == "demon_targettable" and is_targetable:
		# Stay in targettable animation during targetable phase
		anim.play("demon_targettable")
		return

	# Handle targetable animation - when targetable phase ends, go to idle
	if anim and anim.animation == "demon_targettable" and not is_targetable:
		anim.play("demon_idle")
		return

	# Handle attack animation - single attack then reset cycle
	if has_reached_target and anim and anim.animation == "demon_attack":
		# Attack animation finished, deal damage and reset to normal pattern
		print("Demon boss finished ", anim.animation, ", dealing damage and resetting cycle.")
		if target_node:  # Deal damage after attack animation
			target_node.take_damage()
		# Reset to normal pattern (go back to Top and restart cycle)
		become_untargetable()
		return

	# Return to appropriate animation after attack animations
	if anim and anim.animation == "demon_attack":
		# Check if we're currently moving between nodes
		var is_moving = (current_movement_state == MovementState.MOVING_TOP or
						current_movement_state == MovementState.MOVING_RIGHT or
						current_movement_state == MovementState.MOVING_BOTTOM or
						current_movement_state == MovementState.MOVING_LEFT)

		if is_moving:
			anim.play("demon_run")
		else:
			anim.play("demon_idle")

func advance_to_next_position():
	"""Advance to the next position in the cycle: Top → Right → Bottom → Left → Top..."""
	match positions_completed:
		1:
			current_movement_state = MovementState.MOVING_RIGHT
			current_target_position = right_position
			print("Demon boss moving from Top to Right")
		2:
			current_movement_state = MovementState.MOVING_BOTTOM
			current_target_position = bottom_position
			print("Demon boss moving from Right to Bottom")
		3:
			current_movement_state = MovementState.MOVING_LEFT
			current_target_position = left_position
			print("Demon boss moving from Bottom to Left")
		_:
			# Default to Top
			current_movement_state = MovementState.MOVING_TOP
			current_target_position = top_position
			print("Demon boss defaulting to Top position")

func _physics_process(delta: float) -> void:
	# Handle knockback physics (highest priority)
	if is_knockbacked:
		velocity = knockback_velocity
		move_and_slide()

		# Apply room bounds clamping
		clamp_within_room_bounds()

		# Decelerate knockback
		var current_speed = knockback_velocity.length()
		if current_speed > 0.0:
			current_speed = max(0.0, current_speed - knockback_deceleration * delta)
			if current_speed == 0.0:
				# Knockback finished - start targetable phase
				is_knockbacked = false
				start_targetable_phase()
			knockback_velocity = knockback_velocity.normalized() * current_speed
		return

	# Don't move if dead, being targeted, or in targetable phase (except during dash)
	if death_started or (is_being_targeted and current_attack_state != AttackState.DASHING) or (is_targetable and current_attack_state != AttackState.DASHING):
		velocity = Vector2.ZERO
		move_and_slide()
		clamp_within_room_bounds()
		return

	# Handle dash movement during attack phase
	if current_attack_state == AttackState.DASHING:
		# Move toward target like a regular enemy
		var direction = (target_position - global_position).normalized()
		velocity = direction * move_speed

		# Update facing direction
		if anim and direction.x != 0:
			anim.flip_h = direction.x > 0

		# Play run animation only if not attacking
		if anim and anim.animation != "demon_run" and not anim.animation.begins_with("demon_attack"):
			anim.play("demon_run")

		move_and_slide()
		clamp_within_room_bounds()

		# Check proximity to target for attack setup
		_attempt_reach_target_via_proximity()
		return

	# Handle movement between nodes during shooting phase
	if current_attack_state == AttackState.SHOOTING and current_movement_state != MovementState.IDLE:
		var direction = (current_target_position - global_position).normalized()
		velocity = direction * move_speed

		# Play run animation
		if anim and anim.animation != "demon_run":
			anim.play("demon_run")

		# Update facing direction
		if anim and direction.x != 0:
			anim.flip_h = direction.x > 0

		move_and_slide()
		clamp_within_room_bounds()

		# Check if reached target position
		if not has_reached_position and global_position.distance_to(current_target_position) <= 5.0:
			# Reached position - start shooting
			has_reached_position = true
			global_position = current_target_position
			current_movement_state = MovementState.IDLE
			start_shooting_fireballs()
		return

	# Idle or waiting states
	velocity = Vector2.ZERO
	move_and_slide()
	clamp_within_room_bounds()

func _attempt_reach_target_via_proximity():
	"""Detect reaching the target using distance to target_position; do single attack."""
	if has_reached_target:
		return
	# Require a valid target_position to be set
	if not has_target and target_position == Vector2.ZERO:
		return
	if global_position.distance_to(target_position) <= 12.0:
		has_reached_target = true
		has_target = false
		current_attack_state = AttackState.ATTACKING
		print("Demon boss reached target (proximity)! Performing single attack.")

		# Try to locate the Target node for damage calls if not already set
		if target_node == null:
			var possible_target: Node = get_tree().root.find_child("Target", true, false)
			if possible_target and possible_target is Node2D:
				target_node = possible_target

		# Perform single attack
		play_random_attack_animation()

func _on_hack_timer_timeout():
	"""Called every 1.5 seconds to play random attack animation like minotaur"""
	if is_knockbacked:
		return
	# If we drifted away from the target, stop attacking and re-approach
	if target_position != Vector2.ZERO and global_position.distance_to(target_position) > 18.0:
		has_reached_target = false
		current_attack_state = AttackState.DASHING
		if anim and anim.animation.begins_with("attack"):
			anim.play("demon_idle")
		# Resume approach
		set_target_position(target_position)
		return
	if has_reached_target and not is_being_targeted:
		play_random_attack_animation()
		print("Demon boss attacking the target!")

func play_random_attack_animation():
	"""Play the attack animation (demon boss only has one attack animation)"""
	if not anim or anim.animation == "demon_death" or anim.animation == "demon_damaged":
		return

	anim.play("demon_attack")
	print("Demon boss playing attack: demon_attack")

func get_target_node() -> Node2D:
	"""Get the target node to attack"""
	var possible_target = get_tree().root.find_child("Target", true, false)
	if possible_target and possible_target is Node2D:
		return possible_target
	return null

func clamp_within_room_bounds():
	"""Clamp position within room bounds"""
	if room_size == Vector2.ZERO:
		return

	var half = room_size * 0.5
	var min_x = room_center.x - half.x
	var max_x = room_center.x + half.x
	var min_y = room_center.y - half.y
	var max_y = room_center.y + half.y

	var p = global_position
	p.x = clamp(p.x, min_x, max_x)
	p.y = clamp(p.y, min_y, max_y)

	if p != global_position:
		global_position = p
