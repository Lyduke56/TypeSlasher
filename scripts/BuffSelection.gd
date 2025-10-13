extends Control

signal buff_selected(buff_index: int)

func _ready():
	# Connect buff slot buttons
	var grid_container = get_node_or_null("NinePatchRect/VBoxContainer/GridContainer")
	if grid_container:
		for i in range(grid_container.get_child_count()):
			var buff_slot = grid_container.get_child(i)
			# Connect mouse input to this slot with proper binding
			var callable_func = _on_buff_slot_clicked.bind(i)
			buff_slot.gui_input.connect(callable_func)

func _on_buff_slot_clicked(event: InputEvent, slot_index: int):
	"""Handle buff slot click"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Buff slot ", slot_index + 1, " clicked!")

		# Apply buff effect and transition to boss room
		_apply_buff_and_transition(slot_index)

func _apply_buff_and_transition(buff_index: int):
	"""Apply the selected buff and handle scene transition"""
	var global = get_global_node()

	# Apply buff effect based on index
	if buff_index == 0:  # Health buff (Buff_HealthPotion)
		global.health_buff_applied = true
		global.player_max_health += 1
		print("Health buff applied! Max health is now: ", global.player_max_health)

		# Apply to current heart container if available
		var heart_container = find_heart_container()
		if heart_container:
			heart_container.setMaxhearts(global.player_max_health)
			print("Heart container updated with new max health.")
		else:
			print("No heart container found - buff will apply when heart container is created.")

	# For now, all buffs transition to boss room (placeholder behavior)
	print("Buff ", buff_index, " selected - transitioning to boss room")

	# Hide buff selection UI immediately
	queue_free()
	print("Buff selection UI destroyed")

	# Resume the game and change scene immediately
	if get_tree().paused:
		get_tree().paused = false

	# Use call_deferred to ensure queue_free is processed before scene change
	call_deferred("_change_scene")

func _change_scene():
	"""Deferred scene change to avoid crashes"""
	get_tree().change_scene_to_file("res://Scenes/Rooms/Area 1/Area-1-boss-var1.tscn")
	print("Changing scene to boss room!")

func find_heart_container():
	"""Find the heart container in the current scene"""
	var canvas_layer = get_node_or_null("/root/dungeon/CanvasLayer")
	if canvas_layer:
		return canvas_layer.get_node_or_null("HeartContainer")
	return null

func get_global_node():
	"""Get the global singleton node"""
	var global = get_node_or_null("/root/Global")
	if global == null:
		global = load("res://Scripts/global.gd").new()
		get_tree().root.add_child(global)
	return global
