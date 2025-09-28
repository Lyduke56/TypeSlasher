extends Control

signal buff_selected(buff_index: int)

func _ready():
	# Connect buff slot buttons
	var grid_container = get_node_or_null("NinePatchRect/VBoxContainer/GridContainer")
	if grid_container:
		for i in range(grid_container.get_child_count()):
			var buff_slot = grid_container.get_child(i)
			# Connect mouse input to this slot
			buff_slot.gui_input.connect(_on_buff_slot_clicked.bind(i))

func _on_buff_slot_clicked(slot_index: int, event: InputEvent):
	"""Handle buff slot click"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Buff slot ", slot_index + 1, " clicked!")
		buff_selected.emit(slot_index)
