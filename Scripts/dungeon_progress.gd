extends Node

# Dungeon progression system - persists across scene changes
var dungeons_required: int = 4  # Number of dungeons needed to unlock boss
var dungeons_cleared: int = 0
var cleared_dungeons: Array = []  # List of cleared dungeon indices
var current_area: int = 0  # Current area (1, 2, etc.)
var ng_plus_cycle: int = 0 # 0 = Base Game, 1 = NG+1, etc.

# Persistence methods
func reset_progress():
	dungeons_cleared = 0
	cleared_dungeons.clear()

func start_ng_plus(): #NG function
	ng_plus_cycle += 1
	current_area = 1
	reset_progress() # Existing function you already have
	print("ASCENDED: Starting New Game +", ng_plus_cycle)

func advance_to_next_area():
	current_area += 1
	if current_area > 4:  # Loop back to area 1 after area 4
		current_area = 1
	reset_progress()  # Reset dungeon progress for new area

func save_dungeon_count(count: int):
	dungeons_cleared = count

func is_dungeon_cleared(dungeon_name: String) -> bool:
	# Extract variant number (e.g., "Area-1-var-3" -> 2)
	if dungeon_name.begins_with("Area-" + str(current_area) + "-var"):
		var variant_str = dungeon_name.substr(dungeon_name.length() - 1)  # Get last character
		var variant_index = int(variant_str) - 1  # Convert to 0-based index

		if variant_index >= 0 and variant_index < 5:  # Valid range 0-4
			return cleared_dungeons.has(variant_index)
	return false

func mark_dungeon_cleared(dungeon_path: String):
	"""Mark a specific dungeon as completed by its path"""
	var dungeon_name = dungeon_path.get_file().get_basename()  # "Area-X-var-N"

	# Extract the variant number (e.g., "Area-1-var-3" -> 2)
	if dungeon_name.begins_with("Area-" + str(current_area) + "-var"):
		var variant_str = dungeon_name.substr(dungeon_name.length() - 1)  # Get last character
		var variant_index = int(variant_str) - 1  # Convert to 0-based index

		if variant_index >= 0 and variant_index < 5:  # Valid range 0-4
			if not cleared_dungeons.has(variant_index):
				cleared_dungeons.append(variant_index)
				print("Marked dungeon as cleared: ", dungeon_name, " (index: ", variant_index, ")")

func get_available_dungeons() -> Array:
	"""Return array of available dungeon indices (0-4)"""
	var available_dungeons = [0, 1, 2, 3, 4]

	# Remove already cleared dungeons
	for cleared_idx in cleared_dungeons:
		available_dungeons.erase(cleared_idx)

	return available_dungeons

func get_next_random_dungeon() -> String:
	"""Select a random dungeon that hasn't been cleared yet"""
	var available = get_available_dungeons()

	# If no dungeons available, something went wrong - just pick one
	if available.is_empty():
		available = [0, 1, 2, 3, 4]

	# Pick random dungeon from available ones
	var selected_idx = available[randi_range(0, available.size() - 1)]
	var dungeon_name = "Area " + str(current_area) + "/Area-" + str(current_area) + "-var" + str(selected_idx + 1) + ".tscn"
	var dungeon_path = "res://Scenes/Rooms/" + dungeon_name

	print("Loading random dungeon: ", dungeon_path, " from available: ", available)
	return dungeon_path
