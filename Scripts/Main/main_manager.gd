extends Node2D

# Current loaded dungeon scene
var current_dungeon: Node2D = null

# Debug dungeon path - set in editor for testing specific dungeons
@export var debug_dungeon_path: String = ""

# Use the dedicated DungeonProgress autoload for persistence

var pause_ui: Control
var freeze_buff_stacks: int = 0
var freeze_pause_duration: float = 3.0  # Editable in inspector

func boss_dungeon_cleared():
	"""Called when boss dungeon is completed - go to buff selection"""
	print("Boss dungeon cleared! Going to buff selection...")
	# Set flag that we're coming from boss completion
	Global.after_boss_completion = true
	# Go to buff selection
	get_tree().change_scene_to_file("res://Scenes/BuffSelection.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Check if we're coming back from buff selection
	if Global.get("after_buff_selection") == true:
		Global.after_buff_selection = false
		# Print what buff was selected
		print("Returning from buff selection - Slot:", Global.selected_buff_index, " Buff type:", Global.selected_buff_type)

		# Apply buffs based on selected type
		if Global.selected_buff_type == 0:  # Health Potion
			# Apply health buff immediately instead of relying on target.gd
			Global.player_max_health += 1
			Global.player_current_health += 1
			Global.player_health_changed.emit(Global.player_current_health, Global.player_max_health)
			print("Health Potion buff applied! Max health increased to: ", Global.player_max_health, " and current health increased to: ", Global.player_current_health)
		elif Global.selected_buff_type == 1:  # Shield
			Global.shield_buff_stacks += 1
			Global.shield_damage_reduction_chance = Global.shield_buff_stacks * 15  # 15% per stack
			print("Shield buff applied! Now have ", Global.shield_buff_stacks, " stack(s) - ", Global.shield_damage_reduction_chance, "% damage reduction chance")
		elif Global.selected_buff_type == 2:  # Sword
			Global.sword_buff_stacks += 1
			Global.sword_heal_chance = Global.sword_buff_stacks * 15  # 15% per stack
			print("Sword buff applied! Now have ", Global.sword_buff_stacks, " stack(s) - ", Global.sword_heal_chance, "% chance to heal on enemy kills")
		elif Global.selected_buff_type == 3:  # Pause Enemy
			freeze_buff_stacks += 1
			print("Pause enemy buff applied! Now have ", freeze_buff_stacks, " stack(s). Duration: ", freeze_pause_duration)
			# Immediately apply to a random enemy in current dungeon
			_apply_freeze_buff_to_random_enemy()

		# Check if we just completed a boss dungeon
		if Global.get("after_boss_completion") == true:
			Global.after_boss_completion = false
			print("Returning from buff selection after boss completion - advancing to next area")
			# Advance to next area and reset dungeon progress
			DungeonProgress.advance_to_next_area()
			# Load first dungeon of next area
			load_random_dungeon()
		else:
			# After buff selection - continue with dungeon progression using DungeonProgress autoload
			load_random_dungeon()

		# Update heart container in Main scene after health buff application
		call_deferred("_update_main_heart_container")
	else:
		# Load debug dungeon if specified, otherwise load random initial dungeon
		if debug_dungeon_path != "":
			load_dungeon(debug_dungeon_path)
		else:
			load_random_dungeon()
	# Update heart container in Main scene
	call_deferred("_update_main_heart_container")

	# Use custom UI pause menu on a dedicated CanvasLayer, like heart_container
	var ui_canvas = CanvasLayer.new()
	ui_canvas.name = "UICanvas"
	add_child(ui_canvas)

	var ui_scene: PackedScene = preload("res://Scenes/GUI/UI.tscn")
	pause_ui = ui_scene.instantiate()
	ui_canvas.add_child(pause_ui)

	# Ensure it and all children work while paused
	_set_node_tree_process_mode(ui_canvas, Node.ProcessMode.PROCESS_MODE_WHEN_PAUSED)

	# Bring UI to front
	if pause_ui is CanvasItem:
		(pause_ui as CanvasItem).z_index = 4096
	pause_ui.visible = false

	# Connect resume signal
	if pause_ui.has_signal("request_resume_game"):
		pause_ui.connect("request_resume_game", Callable(self, "_resume_game"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func load_dungeon(dungeon_path: String) -> void:
	# Clear current dungeon if exists - ensure proper cleanup
	if current_dungeon:
		# Force immediate cleanup to prevent visual glitches
		current_dungeon.queue_free()
		current_dungeon = null
		# Small delay to ensure cleanup is complete
		await get_tree().process_frame

	# Load new dungeon scene
	var dungeon_scene = load(dungeon_path)
	if dungeon_scene:
		current_dungeon = dungeon_scene.instantiate()
		# Add as child and position it properly
		add_child(current_dungeon)
		print("Loaded dungeon: " + dungeon_path)

		# Connect dungeon signals to prompt display
		connect_dungeon_signals()

		# Ensure player is positioned in the new dungeon's starting room center
		call_deferred("_position_player_in_new_dungeon")
	else:
		print("Failed to load dungeon: " + dungeon_path)

func _position_player_in_new_dungeon() -> void:
	"""Position the player in the center of the new dungeon's starting room"""
	if not current_dungeon:
		return

	# Find the player node
	var player = get_node("/root/Main/Player")
	if not player:
		print("ERROR: Could not find player node")
		return

	# Find the starting room in the current dungeon
	var starting_room = current_dungeon.get_node_or_null("StartingRoom")
	if not starting_room:
		print("ERROR: Could not find StartingRoom in new dungeon")
		return

	# Find the TargetContainer in the starting room (should be the center position)
	var target_container = starting_room.get_node_or_null("TargetContainer")
	if target_container:
		player.global_position = target_container.global_position
		player.center_position = target_container.global_position
		print("Player positioned at StartingRoom center: ", target_container.global_position)
	else:
		# Fallback to room position
		player.global_position = starting_room.global_position
		player.center_position = starting_room.global_position
		print("Player positioned at StartingRoom position (fallback): ", starting_room.global_position)

	# Hide player and play spawn animation after positioning
	player.hide_during_spawn()
	_play_player_spawn_animation(player)

func _update_main_heart_container() -> void:
	"""Update the heart container in the Main scene"""
	var main_scene = get_node("/root/Main")
	if main_scene and main_scene.has_node("HUD/HeartContainer"):
		var heart_container = main_scene.get_node("HUD/HeartContainer")
		if heart_container.has_method("initialize_hearts"):
			heart_container.initialize_hearts()
			print("Updated Main scene heart container with health: ", Global.player_current_health, "/", Global.player_max_health)

func _play_player_spawn_animation(player) -> void:
	"""Play the spawn animation on the player's overlay AnimatedSprite2D and enable movement when it finishes"""
	if player.has_node("Overlay"):
		var overlay = player.get_node("Overlay")
		if overlay is AnimatedSprite2D:
			overlay.visible = true
			overlay.play("spawn")
			print("Playing player spawn animation")

			# Connect to animation finished signal to enable movement when spawn ends
			overlay.animation_finished.connect(func():
				player.show_after_spawn()
				Global.player_can_move = true
				print("Player movement enabled after spawn animation finished")
			)
		else:
			print("ERROR: Overlay is not an AnimatedSprite2D")
	else:
		print("ERROR: Player doesn't have Overlay node")

func switch_to_boss_dungeon() -> void:
	"""Called when player types 'Warp' in portal room"""
	print("Switching to boss dungeon...")

	# Mark current dungeon as cleared
	if current_dungeon:
		mark_dungeon_cleared(current_dungeon.scene_file_path)

	# Check if we have cleared enough dungeons
	dungeon_completed()

func dungeon_completed():
	"""Called when a dungeon is completed - tracks progress and decides next dungeon"""
	DungeonProgress.dungeons_cleared += 1
	print("Dungeon completed! Total cleared: ", DungeonProgress.dungeons_cleared, "/", DungeonProgress.dungeons_required)

	# Buff selection logic based on current area
	if DungeonProgress.current_area == 1 and DungeonProgress.dungeons_cleared == 1:
		print("Buff selection triggered after clearing first dungeon in Area 1!")
		# Go to buff selection scene (leads to more dungeons or boss)
		get_tree().change_scene_to_file("res://Scenes/BuffSelection.tscn")
	elif DungeonProgress.dungeons_cleared == 3:
		print("Buff selection triggered after clearing third dungeon!")
		# Go to buff selection scene (leads to more dungeons)
		get_tree().change_scene_to_file("res://Scenes/BuffSelection.tscn")
	elif DungeonProgress.dungeons_cleared >= DungeonProgress.dungeons_required:
		# Directly enter boss dungeon after meeting requirements (no buff before boss)
		print("All dungeons cleared! Entering boss dungeon...")
		var boss_path = "res://Scenes/Rooms/Area " + str(DungeonProgress.current_area) + "/Area-" + str(DungeonProgress.current_area) + "-boss-var1.tscn"
		load_dungeon(boss_path)
	elif DungeonProgress.dungeons_cleared < DungeonProgress.dungeons_required:
		# Load another random dungeon (between checkpoints)
		load_random_dungeon()

func load_random_dungeon():
	"""Select a random dungeon that hasn't been cleared yet"""
	# Use DungeonProgress autoload for persistent tracking
	var dungeon_path = DungeonProgress.get_next_random_dungeon()
	load_dungeon(dungeon_path)

func mark_dungeon_cleared(dungeon_path: String):
	"""Mark a specific dungeon as completed by its path"""
	DungeonProgress.mark_dungeon_cleared(dungeon_path)

func connect_dungeon_signals():
	"""Connect dungeon signals to the prompt display"""
	if not current_dungeon:
		return

	# Get the prompt display from Main scene
	var prompt_display = get_node("/root/Main/PromptDisplay")
	if not prompt_display:
		print("Warning: Could not find PromptDisplay node")
		return

	# Find the dungeon manager node (search recursively for one that has the signals)
	var dungeon_manager = find_dungeon_manager(current_dungeon)
	if not dungeon_manager:
		print("Warning: Could not find any node with prompt signals in dungeon")
		return

	# Disconnect any existing connections to avoid duplicates
	if dungeon_manager.prompt_updated.is_connected(prompt_display.update_prompt_display):
		dungeon_manager.prompt_updated.disconnect(prompt_display.update_prompt_display)
	if dungeon_manager.prompt_cleared.is_connected(prompt_display.clear_prompt_display):
		dungeon_manager.prompt_cleared.disconnect(prompt_display.clear_prompt_display)

	# Connect dungeon signals to prompt display
	dungeon_manager.prompt_updated.connect(prompt_display.update_prompt_display)
	dungeon_manager.prompt_cleared.connect(prompt_display.clear_prompt_display)

	print("Connected dungeon signals to prompt display")

func find_dungeon_manager(node: Node) -> Node:
	"""Recursively search for a node that has the prompt signals"""
	if node.has_signal("prompt_updated") and node.has_signal("prompt_cleared"):
		return node

	for child in node.get_children():
		var found = find_dungeon_manager(child)
		if found:
			return found

	return null

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

func _apply_freeze_buff_to_random_enemy() -> void:
	"""Apply freeze buff to a random enemy in the current dungeon"""
	if not current_dungeon:
		print("No current dungeon to apply freeze buff")
		return

	var enemies = []
	_find_enemy_nodes(current_dungeon, enemies)
	if enemies.is_empty():
		print("No enemies found to freeze in current dungeon")
		return

	var random_enemy = enemies[randi() % enemies.size()]
	print("Applying freeze to enemy: ", random_enemy.name, " for ", freeze_pause_duration, " seconds")

	# Assume enemy has a pause_enemy method; if not, this will fail gracefully
	if random_enemy.has_method("pause_enemy"):
		random_enemy.pause_enemy(freeze_pause_duration)
	else:
		print("Warning: Enemy does not have pause_enemy method")

func _find_enemy_nodes(node: Node, enemies: Array) -> void:
	"""Recursively find enemy nodes (assuming they have 'Enemy' in name or similar)"""
	if node.name.to_lower().contains("enemy") or node.name.to_lower().contains("boss"):
		enemies.append(node)

	for child in node.get_children():
		_find_enemy_nodes(child, enemies)

func _set_node_tree_process_mode(node: Node, mode: Node.ProcessMode) -> void:
	# Recursively set process mode for a subtree so input works while paused
	node.process_mode = mode
	for child in node.get_children():
		_set_node_tree_process_mode(child, mode)

func _unhandled_input(event: InputEvent) -> void:
	# ESC toggles the pause UI on/off
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused or (pause_ui and pause_ui.visible):
			_resume_game()
		else:
			_pause_game()
		return
