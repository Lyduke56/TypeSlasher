extends Node2D

# Current loaded dungeon scene
var current_dungeon: Node2D = null

# Use the dedicated DungeonProgress autoload for persistence

func boss_dungeon_cleared():
	"""Called when boss dungeon is completed - trigger final buff selection"""
	print("Boss dungeon cleared! Triggering final buff selection...")
	# Clear all progress data for a fresh run
	DungeonProgress.reset_progress()
	# Go to final buff selection
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

		# After buff selection - continue with dungeon progression using DungeonProgress autoload
		load_random_dungeon()

		# Update heart container in Main scene after health buff application
		call_deferred("_update_main_heart_container")
	else:
		# Load a random initial dungeon instead of fixed one
		load_random_dungeon()
		# Update heart container in Main scene
		call_deferred("_update_main_heart_container")

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

	# Buff selection after 1st dungeon and after 3rd dungeon, boss after 4th
	if DungeonProgress.dungeons_cleared == 1:
		print("Buff selection triggered after clearing first dungeon!")
		# Go to buff selection scene (leads to more dungeons or boss)
		get_tree().change_scene_to_file("res://Scenes/BuffSelection.tscn")
	elif DungeonProgress.dungeons_cleared == 3:
		print("Buff selection triggered after clearing third dungeon!")
		# Go to buff selection scene (leads to more dungeons)
		get_tree().change_scene_to_file("res://Scenes/BuffSelection.tscn")
	elif DungeonProgress.dungeons_cleared >= DungeonProgress.dungeons_required:
		# Directly enter boss dungeon after meeting requirements (no buff before boss)
		print("All dungeons cleared! Entering boss dungeon...")
		load_dungeon("res://Scenes/Rooms/Area 1/Area-1-boss-var1.tscn")
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
