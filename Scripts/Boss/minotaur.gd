extends CharacterBody2D

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")

@export var speed: float = 30.0  # Movement speed towards target
@export var boss_health: int = 5  # Boss health, requires 5 hits to defeat
@export var knockback_power: float = 600.0  # Initial knockback speed
@export var knockback_deceleration: float = 2000.0  # How quickly knockback slows down
@export var word_category: String = "medium"  # Category for boss words
@onready var anim = $AnimatedSprite2D
@onready var word: RichTextLabel = $Word
@onready var prompt = $Word
@onready var prompt_text = prompt.text
@onready var heart_container = $"Node2D/HeartContainer"

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

var points_for_kill = 5000

# Boss health system
var max_boss_health: int = 5
var is_knockbacked: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var room_center: Vector2 = Vector2.ZERO
var room_size: Vector2 = Vector2.ZERO
var death_started: bool = false

func _ready() -> void:
	# Initialize boss health
	boss_health = max_boss_health

	# Ensure words are available for refresh
	if typeof(WordDatabase) != TYPE_NIL:
		WordDatabase.load_word_database()

	# Setup health UI
	setup_boss_health_ui()

	# Cache room bounds from CameraArea if available (enemy is under EnemyContainer → parent is room)
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

	# Collision Area2D removed; proximity detection handled in _physics_process
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
	# Boss cannot be set to targeted state in the same way as regular enemies
	# Boss remains targetable throughout the fight, only becomes "targeted visually" temporarily
	if targeted:
		modulate = Color.GRAY  # Temporary visual feedback
		# Don't actually set is_being_targeted = true for boss
	else:
		modulate = Color.WHITE  # Reset color
		is_being_targeted = false  # Reset on completion

func take_damage(attacker_global_position: Vector2 = global_position):
	"""Boss takes damage from player, requires 5 hits to defeat"""
	# Allow lethal damage even during knockback, but ignore if already dead
	if boss_health <= 0:
		return

	boss_health -= 1
	update_boss_health_ui()

	print("Minotaur boss damaged! Health: ", boss_health, "/", max_boss_health)

	# If dead now, play death immediately and skip knockback
	if boss_health <= 0:
		play_death_animation()
		return

	# Refresh the boss's word only on non-lethal hits
	_refresh_word()

	# Perform physics-based knockback away from attacker for non-lethal hit
	perform_knockback(attacker_global_position)

	# Play random damage animation for survival cases (knockback starts it too)
	play_random_damage_animation()

func perform_knockback(attacker_global_position: Vector2):
	"""Apply a move_and_slide-style knockback away from the attacker; avoid knocking toward the target"""
	is_knockbacked = true
	# Stop any ongoing attack cycle on the target
	if hack_timer:
		hack_timer.stop()
		hack_timer.queue_free()
		hack_timer = null
	# Force re-approach after knockback
	has_reached_target = false
	has_target = false
	set_targeted_state(false)

	# Determine direction from attacker to boss at the moment of hit
	var direction = (global_position - attacker_global_position).normalized()
	# If this would move us toward the target, invert so we never knock toward the target
	if target_position != Vector2.ZERO:
		var to_target = (target_position - global_position).normalized()
		if direction.dot(to_target) > 0.0:
			direction = -direction

	knockback_velocity = direction * knockback_power

	# Play a damage animation immediately; taunt will be triggered as knockback ends
	play_random_damage_animation()

func play_random_attack_animation():
	"""Play a random attack animation"""
	if not anim or anim.animation == "death" or anim.animation == "damaged":
		return

	var attack_animations = ["attack_1", "attack_2", "attack_3", "attack_4"]
	var random_attack = attack_animations[randi() % attack_animations.size()]
	anim.play(random_attack)
	print("Minotaur playing attack: ", random_attack)

func play_random_damage_animation():
	"""Play a random damage animation"""
	if not anim or anim.animation == "death":
		return

	var damage_animations = ["damage_1", "damage_2"]
	var random_damage = damage_animations[randi() % damage_animations.size()]
	anim.play(random_damage)
	print("Minotaur taking damage: ", random_damage)

func play_death_animation():
	"""Play death animation immediately and clean up on finish"""
	# Stop any attack loop and motion
	if hack_timer:
		hack_timer.stop()
		hack_timer.queue_free()
		hack_timer = null
	is_knockbacked = false
	has_target = false
	has_reached_target = false
	velocity = Vector2.ZERO

	if not anim:
		queue_free()
		return

	# Prevent multiple death plays
	if death_started or anim.animation == "death":
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
	anim.play("death")
	print("Boss death animation started")

func _on_damage_animation_finished():
	"""Called when damage animation completes - plays death animation"""
	if anim.animation == "damaged":
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
		Global.current_score += points_for_kill
		# Check for Sword buff health restoration
		Global.on_enemy_killed()

		# Boss death doesn't complete the dungeon - that happens when the player types "Warp" in a portal room

		queue_free()  # Remove enemy from scene

func _attempt_reach_target_via_proximity():
	"""Detect reaching the target using distance to target_position; set up attack loop."""
	if has_reached_target:
		return
	# Require a valid target_position to be set
	if not has_target and target_position == Vector2.ZERO:
		return
	if global_position.distance_to(target_position) <= 12.0:
		has_reached_target = true
		has_target = false
		print("Enemy reached target (proximity)! Starting hack timer and playing idle.")

		# Try to locate the Target node for damage calls if not already set
		if target_node == null:
			var possible_target: Node = get_tree().root.find_child("Target", true, false)
			if possible_target and possible_target is Node2D:
				target_node = possible_target

		# Play idle animation immediately
		if anim:
			anim.play("idle")

		# Create and start timer for 1.5 second intervals
		hack_timer = Timer.new()
		add_child(hack_timer)
		hack_timer.wait_time = 1.5
		hack_timer.one_shot = false  # Repeat indefinitely
		hack_timer.timeout.connect(_on_hack_timer_timeout)
		hack_timer.start()

func _on_hack_timer_timeout():
	"""Called every 1.5 seconds to play random attack animation"""
	if is_knockbacked:
		return
	# If we drifted away from the target, stop attacking and re-approach
	if target_position != Vector2.ZERO and global_position.distance_to(target_position) > 18.0:
		has_reached_target = false
		if anim and anim.animation.begins_with("attack"):
			anim.play("idle")
		# Resume approach
		set_target_position(target_position)
		return
	if has_reached_target and not is_being_targeted and anim:
		play_random_attack_animation()
		print("Minotaur attacking the target!")

func _on_animation_finished():
	"""Called when any animation finishes"""
	# Don't interfere with death/damage animations or when enemy is being targeted
	if anim and (anim.animation == "death" or anim.animation == "damaged" or is_being_targeted):
		return

	# Handle random attack animations (boss specific)
	var attack_animations = ["attack_1", "attack_2", "attack_3", "attack_4", "taunt"]
	if has_reached_target and anim and anim.animation in attack_animations:
		# Attack animation finished, go back to idle and take damage
		anim.play("idle")
		print("Minotaur finished ", anim.animation, ", back to idle.")
		if target_node and anim.animation != "taunt":  # Taunt doesn't damage
			target_node.take_damage()
		return

	# Reset knockback state after taunt animation completes
	if is_knockbacked and anim and anim.animation == "taunt":
		is_knockbacked = false
		set_targeted_state(false)  # Reset targeting visual
		# Resume approaching the target after knockback
		if target_position != Vector2.ZERO:
			set_target_position(target_position)
		print("Minotaur taunt complete, resuming approach to target.")

func _refresh_word():
	# Pull a fresh word and update the prompt
	if typeof(WordDatabase) != TYPE_NIL:
		var new_word = WordDatabase.get_random_word(word_category)
		if new_word != "":
			set_prompt(new_word)

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

func _physics_process(delta: float) -> void:
	# Hard guard: if death started, force death animation and no movement
	if death_started:
		velocity = Vector2.ZERO
		if anim and anim.animation != "death":
			anim.play("death")
		return
	# Handle knockback motion using velocity and deceleration
	if is_knockbacked:
		velocity = knockback_velocity
		move_and_slide()
		# Clamp within room bounds if configured
		_clamp_within_room_bounds()

		# Decelerate knockback
		var current_speed = knockback_velocity.length()
		if current_speed > 0.0:
			current_speed = max(0.0, current_speed - knockback_deceleration * delta)
			if current_speed == 0.0 and anim and (anim.animation == "damage_1" or anim.animation == "damage_2"):
				anim.play("taunt")
			knockback_velocity = knockback_velocity.normalized() * current_speed
		return

	# STOP ALL MOVEMENT if being targeted or has reached target
	if is_being_targeted or has_reached_target:
		# Don't override death/damage animations
		if anim and (anim.animation == "death" or anim.animation == "damaged"):
			return
		# When reached target and not being targeted, play idle only if not currently attacking
		if anim and has_reached_target and not is_being_targeted:
			var attack_animations = ["attack_1", "attack_2", "attack_3", "attack_4"]
			if anim.animation not in attack_animations:
				anim.play("idle")
		velocity = Vector2.ZERO
		move_and_slide()
		_clamp_within_room_bounds()
		return

	# Only move if NOT being targeted and hasn't reached target
	if has_target:
		# Move towards target position
		var direction = (target_position - global_position).normalized()
		velocity = direction * speed

		if anim:
			anim.play("run")
			anim.flip_h = direction.x < 0

		move_and_slide()
		_clamp_within_room_bounds()

		# Stop when close enough to target
		if global_position.distance_to(target_position) < 5.0:
			has_target = false
			if anim:
				anim.play("idle")
	else:
		# Idle when no specific target
		if anim:
			anim.play("idle")
		velocity = Vector2.ZERO
		move_and_slide()
		_clamp_within_room_bounds()

	# After moving (or idling), check proximity to target to trigger reach logic
	_attempt_reach_target_via_proximity()

func _clamp_within_room_bounds():
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
