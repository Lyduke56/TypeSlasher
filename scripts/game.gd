extends Node2D
@onready var enemy_container = $EnemyContainer
@onready var spawn_timer: Timer = $Timer
@onready var player = $Player  # Add reference to player

var active_enemy = null
var current_letter_index: int = -1
var EnemyScene = preload("res://scenes/Orc_enemy.tscn")

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
	WordDatabase.load_word_database()
	
	# Test the word database
	print("Testing word database:")
	print("Easy word: ", WordDatabase.get_random_word("easy"))
	print("Medium word: ", WordDatabase.get_random_word("medium"))
	print("Hard word: ", WordDatabase.get_random_word("hard"))
	
	# Connect timer signal and configure
	spawn_timer.wait_time = 1.5  # Spawn every 2.5 seconds
	spawn_timer.start()
	spawn_timer.timeout.connect(spawn_enemy)
	
	# Connect player signal to handle enemy destruction
	player.enemy_reached.connect(_on_enemy_reached)

func _process(_delta):
	# Process input buffer one character per frame for high WPM handling
	if not input_buffer.is_empty() and not is_processing_completion:
		var key_typed = input_buffer.pop_front()
		_process_single_character(key_typed)

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
	enemy_instance.z_index = 2 
	
	# Set spawn position around circle
	var spawn_position = get_spawn_position_around_circle()
	enemy_instance.position = spawn_position
	
	# Set target position (where player currently is)
	var target_position = player.global_position
	
	print("New enemy spawned at:", spawn_position)
	print("Moving towards player at:", target_position) 
	print("Assigned word: ", selected_word)
	
	# Add to enemy container
	enemy_container.add_child(enemy_instance)
	
	# Set the word/prompt for this enemy
	enemy_instance.set_prompt(selected_word)
	
	# Set enemy target (player position)
	enemy_instance.set_target_position(target_position)

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
		
	for enemy in enemy_container.get_children():
		# Skip enemies that are already being targeted or invalid
		if not is_instance_valid(enemy) or enemy.is_being_targeted:
			continue
			
		var prompt = enemy.get_prompt()
		if prompt.length() > 0 and prompt.substr(0, 1).to_lower() == typed_character:
			print("Found new enemy that starts with ", typed_character)
			active_enemy = enemy
			current_letter_index = 1
			active_enemy.set_next_character(current_letter_index)
			break

func _complete_word():
	"""Handle word completion with atomic operation"""
	if is_processing_completion or active_enemy == null or not is_instance_valid(active_enemy):
		return
	
	# Set processing flag to block all other operations
	is_processing_completion = true
	
	var enemy_position = active_enemy.global_position
	var completed_enemy = active_enemy
	
	print("Word completed! Player dashing to enemy at: ", enemy_position)
	
	# Atomically update all state
	completed_enemy.is_being_targeted = true
	completed_enemy.set_targeted_state(true)
	active_enemy = null
	current_letter_index = -1
	
	# Clear input buffer of any remaining inputs
	input_buffer.clear()
	
	# Trigger dash
	player.dash_to_enemy(enemy_position, completed_enemy)
	
	# Reset processing flag after a small delay to ensure dash starts
	await get_tree().create_timer(0.1).timeout
	is_processing_completion = false

func _on_enemy_reached(enemy):
	"""Called when player physically reaches an enemy"""
	print("Player reached enemy! Destroying enemy.")
	
	if enemy != null and is_instance_valid(enemy):
		enemy.play_death_animation()

func _process_single_character(key_typed: String):
	"""Process one character at a time to handle high WPM"""
	if is_processing_completion:
		return
		
	if active_enemy == null:
		find_new_active_enemy(key_typed)
		return
	
	# Validate current enemy
	if not is_instance_valid(active_enemy) or active_enemy.is_being_targeted:
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
		current_letter_index += 1
		
		# Update visual feedback
		if is_instance_valid(active_enemy) and not active_enemy.is_being_targeted:
			active_enemy.set_next_character(current_letter_index)
		
		# Check completion
		if current_letter_index >= prompt.length():
			_complete_word()
	else:
		print("Wrong character! Typed:", key_typed, " Expected:", next_character)
		if active_enemy and is_instance_valid(active_enemy):
			active_enemy.set_next_character(-1)
		active_enemy = null
		current_letter_index = -1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var typed_event = event as InputEventKey
		if typed_event.unicode != 0:
			var key_typed = PackedByteArray([typed_event.unicode]).get_string_from_utf8().to_lower()
			print("Key buffered:", key_typed)
			
			# Add to buffer instead of processing immediately
			input_buffer.append(key_typed)
