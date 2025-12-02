extends Node

var high_score = 0
var current_score: int
var previous_score: int
const HIGH_SCORE_SAVE_PATH = "user://high_score.save"

var best_time: float = 999999.0  # Best completion time in seconds (large initial value)
const BEST_TIME_SAVE_PATH = "user://best_time.save"

# Leaderboard system
var leaderboard_scores: Array = []
const SCORE_FILE = "user://leaderboard.json"

# Flag to track if we're coming back from buff selection
var after_buff_selection: bool = false

# Flag to track if we're coming back from boss completion buff selection
var after_boss_completion: bool = false

# Store selected buff information
var selected_buff_index: int = -1
var selected_buff_type: int = -1

# Flag to track health buff application
var health_buff_applied: bool = false

# Shield buff system (recharging)
var shield_buff_stacks: int = 0:  # How many Shield buffs selected (tiers)
	set(value):
		shield_buff_stacks = value
		calculate_shield_cooldown()
		shield_timer.wait_time = shield_current_cooldown
		if shield_buff_stacks > 0 and not is_shield_ready and shield_timer.is_stopped():
			shield_timer.start()
var is_shield_ready: bool = false
var shield_cooldown_duration: float = 10.0
var shield_current_cooldown: float = 10.0
var shield_timer: Timer

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
	load_high_score()
	load_best_time()
	initialize_freeze_timer()
	initialize_shield_timer()
	initialize_shield()

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

func initialize_shield_timer():
	"""Set up the shield cooldown timer"""
	if not shield_timer:
		shield_timer = Timer.new()
		add_child(shield_timer)
		shield_timer.wait_time = shield_cooldown_duration
		shield_timer.timeout.connect(_on_shield_timer_timeout)
		shield_timer.autostart = false

func calculate_shield_cooldown():
	"""Calculate current shield cooldown based on stacks - base 10s, 20% reduction per additional stack"""
	shield_current_cooldown = shield_cooldown_duration
	for _i in range(1, shield_buff_stacks):
		shield_current_cooldown *= 0.8
	shield_current_cooldown = max(shield_current_cooldown, 1.0)

func initialize_shield():
	"""Initialize shield state - always start false, and start timer if we have buffs with calculated cooldown"""
	# Always start with shield down
	is_shield_ready = false
	shield_status_changed.emit(false)

	calculate_shield_cooldown()
	shield_timer.wait_time = shield_current_cooldown

	if shield_buff_stacks > 0:
		if shield_timer.is_stopped():
			shield_timer.start()
		print("Shield initialized: Starting cooldown timer.")
	else:
		if not shield_timer.is_stopped():
			shield_timer.stop()
		print("Shield initialized: No buffs active.")

func _on_shield_timer_timeout():
	"""When shield recharges, set ready and emit signal"""
	is_shield_ready = true
	shield_status_changed.emit(true)
	print("Shield recharged! Ready to block damage.")

# Player movement control
var player_can_move: bool = false  # Only allow arrow key movement after spawn animation

# Player health system - persists across dungeons
var player_max_health: int = 3  # Default max health, increases permanently
var player_current_health: int = 3  # Current health, resets to max when entering dungeon

signal player_health_changed(new_health: int, max_health: int)
signal buff_stacks_changed()
signal shield_status_changed(is_ready: bool)

func take_damage(amount: int = 1):
	"""Reduce player health, handling shield and death"""
	# Check if shield is ready
	if is_shield_ready:
		# Shield blocks the entire damage
		is_shield_ready = false
		shield_timer.start()  # Start cooldown timer
		shield_status_changed.emit(false)
		print("Shield activated! Damage completely blocked. Cooldown started (10 seconds).")
	else:
		# Take damage normally
		player_current_health -= amount
		if player_current_health < 0:
			player_current_health = 0
		player_health_changed.emit(player_current_health, player_max_health)
		print("Player took ", amount, " damage! Health: ", player_current_health, "/", player_max_health)

		# Check for game over
		if player_current_health <= 0:
			print("Player died! Game Over!")
			# Game over will be handled by a deferred call to allow the heart animation to show
			call_deferred("_handle_game_over")

func _handle_game_over():
	"""Handle game over with a slight delay to show the last heart disappearing"""
	end_game_timer()
	await get_tree().create_timer(0.5).timeout

	# --- RESET BUFFS START ---
	# Reset all buff stacks so they don't carry over to the next game
	shield_buff_stacks = 0
	is_shield_ready = false
	if shield_timer: shield_timer.stop()

	sword_buff_stacks = 0
	sword_heal_chance = 0

	freeze_buff_stacks = 0
	freeze_activation_chance = 0
	if freeze_timer: freeze_timer.stop()

	buff_stacks_changed.emit()
	# --- RESET BUFFS END ---

	player_max_health = 3  # Default max health, increases permanently
	player_current_health = 3  # Current health, resets to max when entering dungeon

	# Reset dungeon progress for future gameplay
	DungeonProgress.reset_progress()
	DungeonProgress.current_area = 1

	get_tree().change_scene_to_file("res://Scenes/game_over.tscn")

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
	"""Recursively find nodes with pause_enemy method (excludes non-enemies, dying enemies, already frozen enemies, and currently targeted enemies)"""
	if node.has_method("pause_enemy") and node.get("is_dying") != true and node.get("is_frozen") != true and node.get("is_being_targeted") != true:  # Only living, unfrozen, untargeted enemies
		enemies.append(node)

	for child in node.get_children():
		_find_enemy_nodes(child, enemies)

# --- High Score Persistence ---
func load_high_score():
	"""Load the high score from disk"""
	if FileAccess.file_exists(HIGH_SCORE_SAVE_PATH):
		var file = FileAccess.open(HIGH_SCORE_SAVE_PATH, FileAccess.READ)
		if file:
			var saved_score = file.get_var()
			if typeof(saved_score) == TYPE_INT:
				high_score = saved_score
			file.close()
			print("Loaded high score: ", high_score)
		else:
			print("Error loading high score file")

func save_high_score():
	"""Save the current high score to disk"""
	var file = FileAccess.open(HIGH_SCORE_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(high_score)
		file.close()
		print("Saved high score: ", high_score)
	else:
		print("Error saving high score file")

func update_high_score(new_score: int):
	"""Update high score if new score is higher, and save to disk"""
	if new_score > high_score:
		high_score = new_score
		save_high_score()
		print("New high score achieved: ", high_score)

# --- Game Timer Tracking ---
var game_start_time: float = 0.0
var game_total_time: float = 0.0

func start_game_timer():
	"""Start the game timer when gameplay begins"""
	game_start_time = Time.get_unix_time_from_system()

func end_game_timer():
	"""End the game timer and calculate total time"""
	if game_start_time > 0.0:
		game_total_time = Time.get_unix_time_from_system() - game_start_time

func get_formatted_time() -> String:
	"""Return formatted time as MM:SS"""
	var minutes = int(game_total_time / 60)
	var seconds = int(game_total_time) % 60
	return "%02d:%02d" % [minutes, seconds]

func load_best_time():
	"""Load the best time from disk"""
	if FileAccess.file_exists(BEST_TIME_SAVE_PATH):
		var file = FileAccess.open(BEST_TIME_SAVE_PATH, FileAccess.READ)
		if file:
			var saved_time = file.get_var()
			if typeof(saved_time) == TYPE_FLOAT:
				best_time = saved_time
			file.close()
			print("Loaded best time: ", get_formatted_best_time())
		else:
			print("Error loading best time file")

func save_best_time():
	"""Save the current best time to disk"""
	var file = FileAccess.open(BEST_TIME_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(best_time)
		file.close()
		print("Saved best time: ", get_formatted_best_time())
	else:
		print("Error saving best time file")

func update_best_time(new_time: float):
	"""Update best time if new time is better, and save to disk"""
	if new_time < best_time:
		best_time = new_time
		save_best_time()
		print("New best time achieved: ", get_formatted_best_time())

func get_formatted_best_time() -> String:
	"""Return formatted best time as MM:SS"""
	var minutes = int(best_time / 60)
	var seconds = int(best_time) % 60
	return "%02d:%02d" % [minutes, seconds]

# --- Leaderboard JSON Persistence ---
func save_scores():
	"""Save the leaderboard scores to JSON file"""
	var file = FileAccess.open(SCORE_FILE, FileAccess.WRITE)
	if file:
		var json_text = JSON.stringify(leaderboard_scores)
		file.store_string(json_text)
		file.close()
		print("Saved leaderboard scores to JSON")
	else:
		print("Error saving leaderboard scores")

func load_scores():
	"""Load the leaderboard scores from JSON file and force sort them"""
	if FileAccess.file_exists(SCORE_FILE):
		var file = FileAccess.open(SCORE_FILE, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(json_text)
			if parsed is Array:
				leaderboard_scores = parsed
				# FIXED SORT: Highest Score First (Descending)
				# Logic: "a" comes before "b" if "a" is larger
				leaderboard_scores.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
			else:
				leaderboard_scores = []
		else:
			print("Error reading leaderboard file")
			leaderboard_scores = []
	else:
		leaderboard_scores = []
	print("Loaded leaderboard scores: ", leaderboard_scores.size())

func add_score(player_name: String, time_str: String, score_val: int):
	"""Add a new score to leaderboard, sort descending by score"""
	load_scores()

	leaderboard_scores.append({"name": player_name, "time": time_str, "score": score_val})

	# FIXED SORT: Highest Score First (Descending)
	leaderboard_scores.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))

	save_scores()
	print("Added new score for ", player_name, ": ", score_val)
