extends "res://Scripts/enemy_base.gd"

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")

@export var speed: float = 67.0  # Movement speed towards target
@export var health: int = 2  # Enemy health, requires block + 2 damage hits to defeat
@export var word_category: String = "medium"  # Category for enemy words

@onready var word: RichTextLabel = $Word
@onready var prompt = $Word
@onready var prompt_text = prompt.text
@onready var area: Area2D = $Area2D
@onready var heart_container = $"Node2D/HeartContainer"
@onready var sfx_damaged: AudioStreamPlayer2D = $sfx_damaged
@onready var sfx_death: AudioStreamPlayer2D = $sfx_death
@onready var sfx_attack: AudioStreamPlayer2D = $sfx_attack

# Target tracking
var target_position: Vector2
var has_target: bool = false

# Targeting state - prevents retyping once word is completed
var is_being_targeted: bool = false

# Block mechanism - blocks first attack, then uses health system for subsequent hits
var has_blocked: bool = false

# Collision state
var has_reached_target: bool = false
var hack_timer: Timer
# Reference to target node for taking damage
var target_node: Node2D

@export var points_for_kill = 100

# Enemy health system
var max_health: int = 3

func _ready() -> void:
	# Initialize enemy health
	max_health = health
	health = max_health

	# Setup health UI
	setup_health_ui()

	# Connect collision signal
	area.body_entered.connect(_on_body_entered)
	# Connect animation finished signal
	if anim:
		anim.animation_finished.connect(_on_animation_finished)
	pass  # Word will be set by the game manager via set_prompt()

func pause_enemy(duration: float) -> void:
	super.pause_enemy(duration)
	if is_frozen and anim:
		anim.play("orc_rider_idle")

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
		# Stop moving and play idle animation when targeted, but don't interrupt special animations
		if anim and anim.animation != "orc_rider_damaged" and anim.animation != "orc_rider_block":
			anim.play("orc_rider_idle")
		modulate = Color.GRAY  # Darken the enemy
	else:
		modulate = Color.WHITE  # Reset color
	# Update word modulate to match
	word.modulate = modulate

func play_death_animation():
	"""Enemy takes damage from player - blocks first hit, then uses health system"""
	if health <= 0:
		return

	if not has_blocked:
		# First hit - block it
		has_blocked = true
		print("Orc rider blocking first attack!")

		# Disconnect any existing connections to prevent duplicates
		if anim.animation_finished.is_connected(_on_block_animation_finished):
			anim.animation_finished.disconnect(_on_block_animation_finished)

		# Play block animation and connect finished signal
		if anim:
			anim.animation_finished.connect(_on_block_animation_finished, CONNECT_ONE_SHOT)
			anim.play("orc_rider_block")
			print("Orc rider block animation started")
		return

	# Subsequent hits - take health damage
	health -= 1
	update_health_ui()

	print("Orc rider damaged! Health: ", health, "/", max_health)

	# If dead now, play death immediately
	if health <= 0:
		perform_death()
		return

	# Refresh the enemy's word only on non-lethal hits
	_refresh_word()

	# Stop targeting temporarily after taking damage
	set_targeted_state(false)

	# Play damage animation for survival cases
	play_damage_animation()


func play_damage_animation():
	"""Play damage animation"""
	if not anim or anim.animation == "orc_rider_death":
		return

	anim.play("orc_rider_damaged")
	$sfx_damaged.play()
	print("Orc rider taking damage")

func perform_death():
	"""Play death animation immediately"""
	# Stop any attack cycle
	if hack_timer:
		hack_timer.stop()
		hack_timer.queue_free()
		hack_timer = null
	has_target = false
	has_reached_target = false

	if not anim:
		queue_free()
		return

	# Prevent multiple death plays
	if anim.animation == "orc_rider_death":
		return

	# Ensure we only listen once for death end
	if anim.animation_finished.is_connected(_on_death_animation_finished):
		anim.animation_finished.disconnect(_on_death_animation_finished)
	anim.animation_finished.connect(_on_death_animation_finished)
	# Disable looping for death animation
	anim.sprite_frames.set_animation_loop("orc_rider_death", false)
	anim.play("orc_rider_death")
	$sfx_death.play()
	print("Enemy death animation started")

func setup_health_ui():
	"""Setup the health UI for the enemy"""
	if heart_container:
		# Clear any existing hearts
		for child in heart_container.get_children():
			if child is Panel:
				child.queue_free()

		# Add the correct number of hearts
		for i in range(max_health):
			var heart_scene: PackedScene = preload("res://Scenes/GUI/HeartGUI.tscn")
			var heart = heart_scene.instantiate()
			if heart and heart is Panel:
				heart_container.add_child(heart)
				# Initially all hearts are visible (full health)
				heart.visible = true

func update_health_ui():
	"""Update the health UI to show remaining enemy hearts"""
	if heart_container:
		var heart_count = heart_container.get_child_count()
		for i in range(heart_count):
			var heart = heart_container.get_child(i)
			if heart and heart is Panel:
				# Show heart if enemy still has health remaining
				heart.visible = (i < health)
		print("Enemy health UI updated: ", health, " hearts remaining")

func _on_block_animation_finished():
	"""Called when block animation completes"""
	if anim.animation == "orc_rider_block":
		# Block animation finished - enemy survives and goes back to idle
		if anim:
			anim.play("orc_rider_idle")
		print("Enemy successfully blocked attack and is back to normal")

		# Reset targeting state to allow the enemy to continue moving
		set_targeted_state(false)

func _refresh_word():
	# Pull a fresh word and update the prompt
	if typeof(WordDatabase) != TYPE_NIL:
		var category_to_use = word_category
		# Adjust for NG+ if enabled
		if Global.ng_plus_enabled and not category_to_use.ends_with("_ng+"):
			var ng_plus_category = category_to_use + "_ng+"
			if WordDatabase.get_category_words(ng_plus_category).size() > 0:
				category_to_use = ng_plus_category
		var new_word = WordDatabase.get_random_word(category_to_use)
		if new_word != "":
			set_prompt(new_word)

func _on_death_animation_finished():
	"""Called when death animation completes"""
	if anim.animation == "orc_rider_death":
		Global.current_score += points_for_kill
		# Check for Sword buff health restoration
		Global.on_enemy_killed()
		queue_free()  # Remove enemy from scene

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
				anim.play("orc_rider_idle")

			# Create and start timer for 1.5 second intervals
			hack_timer = Timer.new()
			add_child(hack_timer)
			hack_timer.wait_time = 1.5
			hack_timer.one_shot = false  # Repeat indefinitely
			hack_timer.timeout.connect(_on_hack_timer_timeout)
			hack_timer.start()

func _on_hack_timer_timeout():
	"""Called every 1.5 seconds to play hack animation"""
	if has_reached_target and not is_being_targeted and anim:
		# Temporarily disable looping for hack animation so it plays once
		anim.sprite_frames.set_animation_loop("orc_rider_attack_2", false)
		anim.play("orc_rider_attack_2")
		$sfx_attack.play()
		print("Enemy hacking the target!")

func _on_animation_finished():
	"""Called when any animation finishes"""
	# Special handling for damaged animation - always process even when being targeted
	if anim and anim.animation == "orc_rider_damaged":
		# Complete damage animation processing
		anim.play("orc_rider_idle")
		print("Enemy finished taking damage, back to idle.")
		return

	# Don't interfere with death/damage/block animations or when enemy is being targeted
	if anim and (anim.animation == "orc_rider_death" or anim.animation == "orc_rider_damaged" or anim.animation == "orc_rider_block" or is_being_targeted):
		return

	if has_reached_target and anim and anim.animation == "orc_rider_attack_2":
		# Hack animation finished, go back to idle and take damage
		anim.play("orc_rider_idle")
		print("Enemy finished hacking, back to idle.")
		if target_node:
			target_node.take_damage()

	if anim.animation == "orc_rider_damaged":
		# Damage animation finished, go back to idle
		anim.play("orc_rider_idle")
		print("Enemy finished taking damage, back to idle.")

func _physics_process(delta: float) -> void:
	# STOP ALL MOVEMENT if frozen, being targeted, or has reached target
	if is_frozen or is_being_targeted or has_reached_target:
		# Don't override death/damage animations
		if anim and (anim.animation == "orc_rider_death" or anim.animation == "orc_rider_damaged"):
			return  # Let death/damage animations play

		# When reached target and not being targeted, play idle only if not currently hacking
		if anim and has_reached_target and not is_being_targeted and anim.animation != "orc_rider_attack_2":
			anim.play("orc_rider_idle")
		return  # Exit function completely - no movement at all

	# Only move if NOT being targeted and hasn't reached target
	if has_target:
		# Move towards target position
		var direction = (target_position - global_position).normalized()

		if anim and anim.animation != "orc_rider_damaged" and anim.animation != "orc_rider_block":
			anim.play("orc_rider_run")
			anim.flip_h = direction.x < 0

		global_position += direction * speed * delta

		# Stop when close enough to target
		if global_position.distance_to(target_position) < 5.0:
			has_target = false
			if anim and anim.animation != "orc_rider_damaged" and anim.animation != "orc_rider_block":
				anim.play("orc_rider_idle")
	else:
		# Fallback: move downward if no specific target
		if anim and anim.animation != "orc_rider_damaged" and anim.animation != "orc_rider_block":
			anim.play("orc_rider_idle")
		global_position.y += speed * delta
