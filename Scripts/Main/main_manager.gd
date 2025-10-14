extends Node2D

# Current loaded dungeon scene
var current_dungeon: Node2D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Check if we're coming back from buff selection
	if Global.get("after_buff_selection") == true:
		Global.after_buff_selection = false
		# Print what buff was selected
		print("Returning from buff selection - Slot:", Global.selected_buff_index, " Buff type:", Global.selected_buff_type)

		# Apply buffs based on selected type
		if Global.selected_buff_type == 0:  # Health Potion
			Global.health_buff_applied = true
			print("Health Potion buff will be applied to target!")
		elif Global.selected_buff_type == 1:  # Shield
			Global.shield_buff_stacks += 1
			Global.shield_damage_reduction_chance = Global.shield_buff_stacks * 15  # 15% per stack
			print("Shield buff applied! Now have ", Global.shield_buff_stacks, " stack(s) - ", Global.shield_damage_reduction_chance, "% damage reduction chance")
		elif Global.selected_buff_type == 2:  # Sword
			Global.sword_buff_stacks += 1
			Global.sword_heal_chance = Global.sword_buff_stacks * 15  # 15% per stack
			print("Sword buff applied! Now have ", Global.sword_buff_stacks, " stack(s) - ", Global.sword_heal_chance, "% chance to heal on enemy kills")

		# Load the boss dungeon after buff selection
		load_dungeon("res://Scenes/Rooms/Area 1/Area-1-boss-var1.tscn")
	else:
		# Load the initial dungeon
		load_dungeon("res://Scenes/Rooms/Area 1/Area-1-var1.tscn")

	# Update heart container in Main scene after any buff application
	call_deferred("_update_main_heart_container")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func load_dungeon(dungeon_path: String) -> void:
	# Clear current dungeon if exists
	if current_dungeon:
		current_dungeon.queue_free()
		current_dungeon = null

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

func _update_main_heart_container() -> void:
	"""Update the heart container in the Main scene"""
	var main_scene = get_node("/root/Main")
	if main_scene and main_scene.has_node("HUD/HeartContainer"):
		var heart_container = main_scene.get_node("HUD/HeartContainer")
		if heart_container.has_method("initialize_hearts"):
			heart_container.initialize_hearts()
			print("Updated Main scene heart container with health: ", Global.player_current_health, "/", Global.player_max_health)

func switch_to_boss_dungeon() -> void:
	print("Switching to boss dungeon...")
	# Change to buff selection scene
	get_tree().change_scene_to_file("res://Scenes/BuffSelection.tscn")
