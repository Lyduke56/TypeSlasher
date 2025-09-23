extends Node2D
@onready var buff_container = $BuffContainer
@onready var enemy_container = $EnemyContainer
@onready var target_container = $TargetContainer
@onready var portal_container = $PortalContainer
@onready var buff_timer: Timer = $Buff_Timer
@onready var spawn_timer: Timer = $Timer
@onready var player = $Player  # Add reference to player
@onready var target = $TargetContainer

var active_enemy = null
var current_letter_index: int = -1
var EnemyScene = preload("res://scenes/Orc_enemy.tscn")
var BuffScene = preload("res://scenes/Buff.tscn")
var TargetScene = preload("res://scenes/target.tscn")
var PortalScene = preload("res://scenes/GreenPortal.tscn")
var _toggle := false
var pause_ui: Control

# Total spawn limits
var max_enemies = 5
var total_enemies_spawned = 0

var max_buffs = 1
var total_buffs_spawned = 0

# Input processing state
var is_processing_completion: bool = false
var input_buffer: Array[String] = []

# Word categories for different difficulty levels
var current_category = "medium"  # Can be: easy, medium, hard, typo, sentence, casing

# Word uniqueness system
var word_history: Array[String] = []  # Track order of words used
var cooldown_period: int = 10  # How many other words must appear before a word can repeat
var spawn_radius: float = 600.0  # Distance from center to spawn enemies

func _ready() -> void:
	$AnimationPlayer.play("fade_in_to_game")
	# Use custom UI pause menu instead of simple overlay
	var ui_scene: PackedScene = preload("res://Scenes/GUI/UI.tscn")
	pause_ui = ui_scene.instantiate()
	add_child(pause_ui)
	# Ensure it and all children work while paused
	_set_node_tree_process_mode(pause_ui, Node.ProcessMode.PROCESS_MODE_WHEN_PAUSED)
	# Bring UI to front
	if pause_ui is CanvasItem:
		(pause_ui as CanvasItem).z_index = 4096
	pause_ui.visible = false
	# Connect resume signal
	if pause_ui.has_signal("request_resume_game"):
		pause_ui.connect("request_resume_game", Callable(self, "_resume_game"))
	WordDatabase.load_word_database()
	# Reset WPM session at game start
	Global.wpm_reset()

	# Test the word database
	print("Testing word database:")
	print("Easy word: ", WordDatabase.get_random_word("easy"))
	print("Medium word: ", WordDatabase.get_random_word("medium"))
	print("Hard word: ", WordDatabase.get_random_word("hard"))

	# Spawn the target at the start
	spawn_target()

	# Connect timer signal and configure
	spawn_timer.wait_time = 3  # Spawn every 3 seconds
	spawn_timer.start()
	spawn_timer.timeout.connect(spawn_enemy)

	# Connect timer signal and configure
	buff_timer.wait_time = 10  # Spawn every 10 seconds
	buff_timer.start()
	buff_timer.timeout.connect(spawn_buff)

	# Connect player signal to handle enemy destruction
	player.enemy_reached.connect(_on_enemy_reached)
	player.slash_completed.connect(_on_player_slash_completed)

func _process(_delta):
	# Process input buffer one character per frame for high WPM handling
	if not input_buffer.is_empty() and not is_processing_completion:
		update_score() #new high score thing will replace if necessary
		var key_typed = input_buffer.pop_front()
		_process_single_character(key_typed)

func update_score():
	Global.previous_score = Global.current_score
	if Global.current_score > Global.high_score:
		Global.high_score = Global.current_score


func get_unique_word() -> String:
	"""Get a word that hasn't appeared in the last 10 words"""
	var available_words = WordDatabase.get_category_words(current_category)
	if available_words.is_empty():
		print("No words available in category: ", current_category)
		return ""

	# Find words that are NOT in the recent history (last 10 words)
	var eligible_words = []
	for word in available_words:
		if not word in word_history:
			eligible_words.append(word)

	# If no eligible words (shouldn't happen with enough words in database),
	# allow the oldest words from history
	if eligible_words.is_empty():
		print("Warning: Not enough unique words in database for cooldown period")
		# Take words from the beginning of history (oldest ones)
		var words_to_allow = word_history.slice(0, min(5, word_history.size()))
		for word in available_words:
			if word in words_to_allow:
				eligible_words.append(word)

	# Pick random word from eligible words
	var selected_word = eligible_words[randi() % eligible_words.size()]

	# Add to history
	word_history.append(selected_word)

	# Keep only the last 'cooldown_period' words in history
	if word_history.size() > cooldown_period:
		word_history.pop_front()  # Remove oldest word

	print("Selected word: ", selected_word)
	print("Recent history (", word_history.size(), "/", cooldown_period, "): ", word_history)
	return selected_word

func get_spawn_position_around_circle() -> Vector2:
	"""Generate spawn position around a circle, outside the play area"""
	var angle = randf() * 2 * PI  # Random angle in radians
	var spawn_pos = Vector2(
		cos(angle) * spawn_radius,
		sin(angle) * spawn_radius
	)
	return spawn_pos

func spawn_enemy():
	# Check if we've reached the total enemy limit
	if total_enemies_spawned >= max_enemies:
		spawn_timer.stop()
		return

	# Check if the category has words available
	var available_words = WordDatabase.get_category_words(current_category)
	if available_words.is_empty():
		print("No words available in category: ", current_category)
		return

	# Wait one frame to ensure the node is fully in the scene tree
	await get_tree().process_frame

	# Get unique word from current category
	var selected_word = get_unique_word()
	if selected_word == "":
		return

	# Create enemy instance
	var enemy_instance = EnemyScene.instantiate()
	enemy_instance.z_index = 3

	# Set spawn position around circle
	var spawn_position = get_spawn_position_around_circle()
	enemy_instance.position = spawn_position

	# Set target position (where the target is located)
	var target_position = Vector2.ZERO
	if target_container.get_child_count() > 0:
		var target_instance = target_container.get_child(0)
		target_position = target_instance.global_position

	print("New enemy spawned at:", spawn_position)
	print("Moving towards target at:", target_position)
	print("Assigned word: ", selected_word)

	# Add to enemy container
	enemy_container.add_child(enemy_instance)
	total_enemies_spawned += 1

	# Set the word/prompt for this enemy
	enemy_instance.set_prompt(selected_word)

	# Set enemy target (target position)
	enemy_instance.set_target_position(target_position)

func spawn_target():
	var target_instance = TargetScene.instantiate()
	target_container.add_child(target_instance)
	target_instance.position = target_container.position
	target_instance.z_index = 1

# Function to change difficulty/category
func set_word_category(category: String):
	var valid_categories = ["easy", "medium", "hard", "typo", "sentence", "casing"]
	if category in valid_categories:
		current_category = category
		print("Word category changed to: ", category)
	else:
		print("Invalid category: ", category)

func find_new_active_enemy(typed_character: String):
	# Don't allow new enemy selection if we're processing a completion
	if is_processing_completion:
		return

	# Check enemy_container, buff_container, and portal_container for targetable entities
	for container in [enemy_container, buff_container, portal_container]:
		for entity in container.get_children():
			# Skip invalid entities or entities that don't have typing interface
			if not is_instance_valid(entity) or not entity.has_method("get_prompt"):
				continue
			# Skip entities that are already being targeted
			if entity.get("is_being_targeted") == true:
				continue

			var prompt = entity.get_prompt()
			if prompt.length() > 0 and prompt.substr(0, 1).to_lower() == typed_character:
				print("Found new entity that starts with ", typed_character)
				active_enemy = entity
				current_letter_index = 1
				active_enemy.set_next_character(current_letter_index)
				break
		if active_enemy != null:
			break

func _complete_word():
	"""Handle word completion with atomic operation"""
	if is_processing_completion or active_enemy == null or not is_instance_valid(active_enemy):
		return

	# Set processing flag to block all other operations
	is_processing_completion = true

	var entity_position = active_enemy.global_position
	var completed_entity = active_enemy

	print("Word completed! Entity at: ", entity_position)

	# Atomically update all state
	if completed_entity.has_method("set_targeted_state"):
		completed_entity.set("is_being_targeted", true)
		completed_entity.set_targeted_state(true)

	active_enemy = null
	current_letter_index = -1

	# Clear input buffer of any remaining inputs
	input_buffer.clear()

	# Handle completion differently for buffs vs enemies vs portals
	if completed_entity.get_parent() == buff_container:
		# For buffs, just play death animation immediately (no dash needed)
		print("Buff completed! Triggering buff collection.")
		completed_entity.play_death_animation()
	elif completed_entity.get_parent() == portal_container:
		# For portals, dash to portal and change scene
		print("Portal completed! Player dashing to portal and changing scene.")
		player.dash_to_portal(entity_position, completed_entity)
	else:
		# For enemies, trigger dash to enemy
		print("Enemy completed! Player dashing to enemy.")
		player.dash_to_enemy(entity_position, completed_entity)

	# Reset processing flag after a small delay to ensure actions start
	await get_tree().create_timer(0.1).timeout
	is_processing_completion = false

func _on_enemy_reached(enemy):
	"""Called when player physically reaches an enemy - now just for slash animation"""
	print("Player reached enemy! Starting slash animation.")
	# Don't kill enemy here - let the player's slash animation handle it

# NEW FUNCTION: Connect this to player's slash_completed signal
func _on_player_slash_completed(enemy):
	"""Called when player finishes slash animation on an enemy"""
	print("Player slash completed! Now triggering enemy death.")

	if enemy != null and is_instance_valid(enemy):
		enemy.play_death_animation()

	# Check for zone completion after enemy death
	check_zone_completion()

func check_zone_completion():
	"""Check if all enemies are defeated and spawn portals"""
	print("Checking zone completion: total_enemies_spawned=", total_enemies_spawned, " max_enemies=", max_enemies, " enemy_count=", enemy_container.get_child_count())
	if total_enemies_spawned >= max_enemies and enemy_container.get_child_count() == 0:
		print("Zone cleared! Spawning portals.")
		spawn_portals()
	else:
		# If close to completion, check again after a delay
		if total_enemies_spawned >= max_enemies and enemy_container.get_child_count() <= 1:
			print("Almost cleared, checking again in 1 second.")
			await get_tree().create_timer(1.0).timeout
			check_zone_completion()

func spawn_portals():
	"""Spawn 3 portals at predefined positions for zone transition"""
	await get_tree().create_timer(1.0).timeout
	var portal_nodes = [$PortalContainer/Top, $PortalContainer/Left, $PortalContainer/Right]

	for i in range(3):
		var portal_instance = PortalScene.instantiate()
		portal_instance.position = portal_nodes[i].position
		portal_instance.z_index = 8
		portal_instance.portal_index = i
		portal_instance.portal_selected.connect(_on_portal_selected)
		$PortalContainer.add_child(portal_instance)
		portal_instance.play_appear_animation()
		print("Spawned portal ", i + 1, " at position: ", portal_nodes[i].position)

func _on_portal_selected(portal_index: int):
	"""Handle portal selection for zone transition"""
	print("Portal ", portal_index + 1, " selected! Transitioning to next zone.")
	# For now, just clean up portals
	cleanup_portals()

func cleanup_portals():
	"""Remove all portals from the scene"""
	for portal in $PortalContainer.get_children():
		if portal.has_method("play_disappear_animation"):
			portal.play_disappear_animation()
	# Wait a bit for animations, but since they queue_free, maybe not needed

func _process_single_character(key_typed: String):
	"""Process one character at a time to handle high WPM"""
	if is_processing_completion:
		return

	if active_enemy == null:
		find_new_active_enemy(key_typed)
		return

	# Validate current enemy
	if not is_instance_valid(active_enemy) or not active_enemy.has_method("get_prompt") or active_enemy.get("is_being_targeted") == true:
		active_enemy = null
		current_letter_index = -1
		find_new_active_enemy(key_typed)
		return

	var prompt = active_enemy.get_prompt().to_lower()

	# Bounds check
	if current_letter_index < 0 or current_letter_index >= prompt.length():
		print("Index out of bounds, resetting")
		active_enemy = null
		current_letter_index = -1
		return

	var next_character = prompt.substr(current_letter_index, 1)
	if key_typed == next_character:
		print("Success! Typed:", key_typed, " Expected:", next_character)
		# Count one correct character for WPM
		Global.wpm_note_correct_characters(1)
		current_letter_index += 1

		# Update visual feedback
		if is_instance_valid(active_enemy) and active_enemy.get("is_being_targeted") != true:
			active_enemy.set_next_character(current_letter_index)

		# Check completion
		if current_letter_index >= prompt.length():
			_complete_word()
	else:
		print("Wrong character! Typed:", key_typed, " Expected:", next_character)


func _unhandled_input(event: InputEvent) -> void:
	# ESC pauses. Resume only by clicking the overlay.
	if event.is_action_pressed("ui_cancel"): # ESC is mapped to ui_cancel by default
		if not get_tree().paused:
			_pause_game()
		return

	if get_tree().paused:
		return

	if event is InputEventKey and event.pressed:
		var typed_event := event as InputEventKey
		if typed_event.unicode != 0:
			var key_typed = PackedByteArray([typed_event.unicode]).get_string_from_utf8().to_lower()
			print("Key buffered:", key_typed)
			input_buffer.append(key_typed)

func spawn_buff() -> void:
	# Check if we've reached the total buff limit
	if total_buffs_spawned >= max_buffs:
		buff_timer.stop()
		return

	# Wait a frame so scene tree is safe (mirrors your enemy spawn)
	await get_tree().process_frame

	var buff_instance := BuffScene.instantiate()
	buff_instance.z_index = 2

	# Choose a random position near the center so player can see it.
	var radius_min: float = 150.0
	var radius_max: float = 350.0
	var angle: float = randf() * TAU
	var r: float = lerpf(radius_min, radius_max, randf())
	var pos: Vector2 = Vector2(cos(angle), sin(angle)) * r
	buff_instance.position = pos

	# Give it a word (green-colored typing handled inside Buff.gd)
	var available_words: Array = WordDatabase.get_category_words(current_category)
	if available_words.is_empty():
		return
	var w: String = String(available_words[randi() % available_words.size()])
	buff_instance.set_prompt(w)

	# Add to the SAME container so your input/selection loop can target it
	buff_container.add_child(buff_instance)
	total_buffs_spawned += 1

	print("Spawned buff at ", pos, " with word: ", w)


func _pause_game() -> void:
	get_tree().paused = true
	if pause_ui:
		pause_ui.visible = true
		pause_ui.grab_focus()
	# Inform WPM tracker
	Global.wpm_on_pause()

func _resume_game() -> void:
	get_tree().paused = false
	if pause_ui:
		pause_ui.visible = false
	# Inform WPM tracker
	Global.wpm_on_resume()

func _set_node_tree_process_mode(node: Node, mode: Node.ProcessMode) -> void:
	# Recursively set process mode for a subtree so input works while paused
	node.process_mode = mode
	for child in node.get_children():
		_set_node_tree_process_mode(child, mode)
