extends Node

var high_score = 0
var current_score: int
var previous_score: int

# Flag to track if we're coming back from buff selection
var after_buff_selection: bool = false

# Flag to track if we're coming back from boss completion buff selection
var after_boss_completion: bool = false

# Store selected buff information
var selected_buff_index: int = -1
var selected_buff_type: int = -1

# Flag to track health buff application
var health_buff_applied: bool = false

# Shield buff system (for damage reduction)
var shield_buff_stacks: int = 0  # How many Shield buffs selected (tiers)
var shield_damage_reduction_chance: int = 0  # Calculated chance (15% per stack)

# Sword buff system (for health restoration on kills)
var sword_buff_stacks: int = 0  # How many Sword buffs selected (tiers)
var sword_heal_chance: int = 0  # Calculated chance (15% per stack)

# Freeze buff system (for pausing enemies)
var freeze_buff_stacks: int = 0
var freeze_activation_chance: int = 0  # Calculated chance (15% per stack)
@export var freeze_pause_duration: float = 3.0
@export var freeze_timer_interval: float = 5.0

var freeze_timer: Timer

func _ready():
	"""Initialize global systems"""
	initialize_freeze_timer()

func initialize_freeze_timer():
	"""Set up the freeze timer"""
	if not freeze_timer:
		freeze_timer = Timer.new()
		add_child(freeze_timer)
		freeze_timer.wait_time = freeze_timer_interval
		freeze_timer.timeout.connect(_on_freeze_timer_timeout)
		freeze_timer.autostart = false

func update_freeze_chance():
	"""Update freeze activation chance based on stacks"""
	freeze_activation_chance = freeze_buff_stacks * 100
	if freeze_buff_stacks > 0:
		freeze_timer.start()
	else:
		freeze_timer.stop()

func _on_freeze_timer_timeout():
	"""Timer callback to attempt freeze activation"""
	if freeze_buff_stacks > 0 and freeze_activation_chance > 0:
		var chance = randf() * 100
		if chance < freeze_activation_chance:
			pause_enemy_by_buff()

# Player movement control
var player_can_move: bool = false  # Only allow arrow key movement after spawn animation

# Player health system - persists across dungeons
var player_max_health: int = 3  # Default max health, increases permanently
var player_current_health: int = 3  # Current health, resets to max when entering dungeon

signal player_health_changed(new_health: int, max_health: int)
signal buff_stacks_changed()

func take_damage(amount: int = 1):
	"""Reduce player health and emit signal for UI updates"""
	# Check for Shield buff damage reduction
	var actual_damage = amount
	var shielded = false

	if shield_damage_reduction_chance > 0:
		var chance = randf() * 100  # Generate random number 0-100
		if chance < shield_damage_reduction_chance:
			actual_damage = 0
			shielded = true
			print("Shield buff activated! Damage completely blocked (", shield_damage_reduction_chance, "% chance)")

	player_current_health -= actual_damage
	if player_current_health < 0:
		player_current_health = 0
	player_health_changed.emit(player_current_health, player_max_health)

	if shielded:
		print("Player shielded! No damage taken! Health: ", player_current_health, "/", player_max_health)
	else:
		print("Player took ", actual_damage, " damage! Health: ", player_current_health, "/", player_max_health)
			# Check for game over

	if player_current_health <= 0:
		print("Player died! Game Over!")
		# Game over will be handled by a deferred call to allow the heart animation to show
		call_deferred("_handle_game_over")

func _handle_game_over():
	"""Handle game over with a slight delay to show the last heart disappearing"""
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://Scenes/game_over.tscn")
	player_max_health = 3  # Default max health, increases permanently
	player_current_health = 3  # Current health, resets to max when entering dungeon

func heal_damage(amount: int = 1):
	"""Increase player health and emit signal for UI updates"""
	player_current_health += amount
	if player_current_health > player_max_health:
		player_current_health = player_max_health
	player_health_changed.emit(player_current_health, player_max_health)
	print("Player healed ", amount, " health! Health: ", player_current_health, "/", player_max_health)

func on_enemy_killed():
	"""Called when any enemy is killed - check for Sword buff health restoration"""
	if sword_buff_stacks > 0 and sword_heal_chance > 0:
		var chance = randf() * 100  # Generate random number 0-100
		if chance < sword_heal_chance:
			if player_current_health < player_max_health:
				player_current_health += 1  # Restore 1 health
				player_health_changed.emit(player_current_health, player_max_health)
				print("Sword buff activated! Restored 1 health! Health: ", player_current_health, "/", player_max_health)
			else:
				print("Sword buff activated but health already full! Health: ", player_current_health, "/", player_max_health)

# --- WPM tracking ---
# We measure characters typed correctly; 5 characters = 1 word (standard WPM)
var wpm_session_started: bool = false
var wpm_start_time_seconds: float = 0.0
var wpm_paused_total_seconds: float = 0.0
var wpm_pause_started_at_seconds: float = 0.0
var wpm_correct_characters: int = 0

func wpm_reset():
	wpm_session_started = false
	wpm_start_time_seconds = 0.0
	wpm_paused_total_seconds = 0.0
	wpm_pause_started_at_seconds = 0.0
	wpm_correct_characters = 0

func wpm_start_if_needed():
	if not wpm_session_started:
		wpm_session_started = true
		wpm_start_time_seconds = Time.get_ticks_msec() / 1000.0
		wpm_paused_total_seconds = 0.0
		wpm_pause_started_at_seconds = 0.0
		wpm_correct_characters = 0

func wpm_on_pause():
	# Called when game pauses
	if wpm_session_started and wpm_pause_started_at_seconds == 0.0:
		wpm_pause_started_at_seconds = Time.get_ticks_msec() / 1000.0

func wpm_on_resume():
	# Called when game resumes
	if wpm_session_started and wpm_pause_started_at_seconds > 0.0:
		var now_s = Time.get_ticks_msec() / 1000.0
		wpm_paused_total_seconds += max(0.0, now_s - wpm_pause_started_at_seconds)
		wpm_pause_started_at_seconds = 0.0

func wpm_note_correct_characters(num_chars: int = 1):
	# Record correctly typed characters
	wpm_start_if_needed()
	wpm_correct_characters += max(0, num_chars)

func get_wpm() -> float:
	if not wpm_session_started:
		return 0.0
	var now_s = Time.get_ticks_msec() / 1000.0
	var elapsed_s = max(0.0, now_s - wpm_start_time_seconds)
	# Subtract currently paused span if in pause
	var effective_paused = wpm_paused_total_seconds
	if wpm_pause_started_at_seconds > 0.0:
		effective_paused += max(0.0, now_s - wpm_pause_started_at_seconds)
	var active_seconds = max(0.0, elapsed_s - effective_paused)
	if active_seconds <= 0.0:
		return 0.0
	var words_typed = float(wpm_correct_characters) / 5.0
	return words_typed / (active_seconds / 60.0)

func pause_enemy_by_buff():
	"""Pause a random enemy using Buff system - global accessible"""
	var enemies = []
	_find_enemy_nodes(get_tree().root, enemies)
	if enemies.is_empty():
		print("No enemies found to freeze globally")
		return

	var random_enemy = enemies[randi() % enemies.size()]
	print("Pausing enemy globally: ", random_enemy.name, " for ", freeze_pause_duration, " seconds")

	if random_enemy.has_method("pause_enemy"):
		random_enemy.pause_enemy(freeze_pause_duration)
	else:
		print("Warning: Enemy does not support pause_enemy method")

func _find_enemy_nodes(node: Node, enemies: Array):
	"""Recursively find nodes with pause_enemy method (excludes non-enemies)"""
	if node.has_method("pause_enemy"):  # Only enemies have this method
		enemies.append(node)

	for child in node.get_children():
		_find_enemy_nodes(child, enemies)
