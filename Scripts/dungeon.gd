extends Node2D

var BuffSelectionScene = preload("res://scenes/BuffSelection.tscn")
var buff_selection_ui: Control

func _ready():
	# Show buff selection when the dungeon scene loads
	await get_tree().create_timer(0.5).timeout  # Small delay to let scene load
	show_buff_selection()

func show_buff_selection():
	"""Show the buff selection UI when entering the dungeon"""
	# Pause the game
	get_tree().paused = true
	
	# Create and show buff selection UI
	buff_selection_ui = BuffSelectionScene.instantiate()
	add_child(buff_selection_ui)
	
	# Ensure it works while paused
	_set_node_tree_process_mode(buff_selection_ui, Node.ProcessMode.PROCESS_MODE_WHEN_PAUSED)
	
	# Bring UI to front
	if buff_selection_ui is CanvasItem:
		(buff_selection_ui as CanvasItem).z_index = 4096
	
	# Connect buff selection signal
	if buff_selection_ui.has_signal("buff_selected"):
		buff_selection_ui.connect("buff_selected", Callable(self, "_on_buff_selected"))
	
	print("Buff selection UI shown in dungeon!")

func _on_buff_selected(buff_index: int):
	"""Handle buff selection and transition to boss room"""
	print("Buff ", buff_index + 1, " selected! Transitioning to boss room.")

	# Apply buff effect based on index
	if buff_index == 0:  # Assuming Buff_HealthPotion is the first buff (index 0)
		# Find heart container in the current scene and increase max health
		var heart_container = get_node("../CanvasLayer/HeartContainer")
		if heart_container and heart_container.has_method("increaseMaxHealth"):
			heart_container.increaseMaxHealth(1)
			print("Health buff applied! Max health increased by 1.")
		else:
			print("Warning: Could not find HeartContainer to apply health buff")

	# Hide buff selection UI
	if buff_selection_ui:
		buff_selection_ui.queue_free()
		buff_selection_ui = null

	# Do NOT resume the game (keep pause) and change to boss room
	# Note: Scene change will unpause automatically
	get_tree().change_scene_to_file("res://Scenes/Rooms/Area 1/Area-1-boss-var1.tscn")

func _set_node_tree_process_mode(node: Node, mode: Node.ProcessMode) -> void:
	# Recursively set process mode for a subtree so input works while paused
	node.process_mode = mode
	for child in node.get_children():
		_set_node_tree_process_mode(child, mode)
