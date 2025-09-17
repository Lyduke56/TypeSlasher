extends Node2D
@onready var enemy_container = $EnemyContainer
@onready var target_container = $TargetContainer
@onready var spawn_timer: Timer = $Timer
@onready var player = $Player  # Add reference to player
@onready var target = $TargetContainer

var active_enemy = null
var current_letter_index: int = -1
var EnemyScene = preload("res://scenes/Orc_enemy.tscn")
var BuffScene = preload("res://scenes/Buff.tscn")
var TargetScene = preload("res://scenes/target.tscn")
var _toggle := false
var pause_layer: CanvasLayer
var pause_overlay: Control

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
	_build_pause_overlay()
	WordDatabase.load_word_database()

	# Test the word database
	print("Testing word database:")
	print("Easy word: ", WordDatabase.get_random_word("easy"))
	print("Medium word: ", WordDatabase.get_random_word("medium"))
	print("Hard word: ", WordDatabase.get_random_word("hard"))

	# Spawn the target at the start
	spawn_target()

	# Connect timer signal and configure
	spawn_timer.wait_time = 2.5  # Spawn every 2.5 seconds
	spawn_timer.start()
	spawn_timer.timeout.connect(spawn_enemy)

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
	# Check if the category has words available
	var available_words = WordDatabase.get_category_words(current_category)
	if available_words.is_empty():
		print("No words available in category: ", current_category)
		return

	_toggle = not _toggle
	if _toggle:
		spawn_buff()
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

	# Store reference to this enemy for death after slash
	# We'll trigger death when player finishes slash animation, not when reaching enemy

	active_enemy = null
	current_letter_index = -1

	# Clear input buffer of any remaining inputs
	input_buffer.clear()

	# Trigger dash and pass the enemy reference so player can kill it after slash
	player.dash_to_enemy(enemy_position, completed_enemy)

	# Reset processing flag after a small delay to ensure dash starts
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
	enemy_container.add_child(buff_instance)

	print("Spawned buff at ", pos, " with word: ", w)


func _build_pause_overlay() -> void:
	pause_layer = CanvasLayer.new()
	add_child(pause_layer)

	# Make the layer and overlay process while paused
	pause_layer.process_mode = Node.ProcessMode.PROCESS_MODE_WHEN_PAUSED

	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.process_mode = Node.ProcessMode.PROCESS_MODE_WHEN_PAUSED  # <— was pause_mode
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.anchor_left = 0.0
	pause_overlay.anchor_top = 0.0
	pause_overlay.anchor_right = 1.0
	pause_overlay.anchor_bottom = 1.0
	pause_overlay.visible = false
	pause_layer.add_child(pause_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dim.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pause_overlay.add_child(dim)

	var label := Label.new()
	label.text = "Paused — Click to continue"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	pause_overlay.add_child(label)

	pause_overlay.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_resume_game()
	)

func _pause_game() -> void:
	get_tree().paused = true
	pause_overlay.visible = true

func _resume_game() -> void:
	get_tree().paused = false
	pause_overlay.visible = false
