extends Control

signal buff_selected(buff_index: int)

@onready var resetButton = $NinePatchRect/VBoxContainer/ResetButton

func _ready():
	# Connect buff slot buttons
	var grid_container = get_node_or_null("NinePatchRect/VBoxContainer/GridContainer")
	if grid_container:
		for i in range(grid_container.get_child_count()):
			var buff_slot = grid_container.get_child(i)
			if buff_slot:
				# Store the slot index for later use
				buff_slot.set_meta("slot_index", i)
				# Connect mouse input to this slot
				buff_slot.gui_input.connect(_on_buff_slot_clicked)
	resetButton.pressed.connect(_on_reset_button_pressed)
	update_reset_button()

# Called when the scene becomes active
func _enter_tree():
	# Make sure we respond to mouse clicks even if we're a scene root
	mouse_filter = Control.MOUSE_FILTER_PASS

func _on_buff_slot_clicked(event: InputEvent):
	"""Handle buff slot click"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# The signal sender is the buff slot node that received the input
		# So we can directly access it via the callback
		var clicked_slot = get_viewport().gui_get_focus_owner()
		if not clicked_slot or not clicked_slot.has_meta("slot_index"):
			# Try to find it by checking the scene tree
			clicked_slot = _find_buff_slot_under_mouse()
			if not clicked_slot:
				print("Could not determine which buff slot was clicked")
				return

		var buff_index = clicked_slot.get_meta("slot_index")
		var chosen_buff = clicked_slot.get("chosen_index")
		var buff_icons = clicked_slot.get("buff_icons")

		if buff_icons and chosen_buff >= 0 and chosen_buff < buff_icons.size():
			# Determine buff type based on index
			var buff_type = ""
			if chosen_buff == 0:
				buff_type = "Health Potion"
			elif chosen_buff == 1:
				buff_type = "Shield"
			elif chosen_buff == 2:
				buff_type = "Sword"

			print("Buff slot ", buff_index + 1, " clicked! Selected buff: ", buff_type, " (index: ", chosen_buff, ")")

			# Set flag that we're coming from buff selection
			Global.after_buff_selection = true
			# Store the selected buff index for use after scene change
			Global.selected_buff_index = buff_index
			Global.selected_buff_type = chosen_buff
		else:
			print("Buff slot ", buff_index + 1, " clicked! Could not determine buff type (chosen_index: ", chosen_buff, ")")

			# Set flag that we're coming from buff selection even if buff type unknown
			Global.after_buff_selection = true
			Global.selected_buff_index = buff_index
			Global.selected_buff_type = -1

		# Go back to main scene
		get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _find_buff_slot_under_mouse() -> Node:
	"""Find the buff slot under the mouse cursor"""
	var grid_container = get_node_or_null("NinePatchRect/VBoxContainer/GridContainer")
	if grid_container:
		var mouse_pos = get_viewport().get_mouse_position()
		for child in grid_container.get_children():
			if child.has_meta("slot_index") and child.is_visible_in_tree():
				var rect = child.get_global_rect()
				if rect.has_point(mouse_pos):
					return child
	return null

func _on_reset_button_pressed():
	if Global.buff_resets_available > 0:
		Global.buff_resets_available -= 1
		var grid_container = get_node_or_null("NinePatchRect/VBoxContainer/GridContainer")
		if grid_container:
			for buff_slot in grid_container.get_children():
				if buff_slot.has_method("reroll"):
					buff_slot.reroll()
		update_reset_button()

func update_reset_button():
	resetButton.text = "Reset (" + str(Global.buff_resets_available) + ")"
	if Global.buff_resets_available == 0:
		resetButton.disabled = true
