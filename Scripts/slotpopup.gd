extends PanelContainer # Or Control, depending on your root node type

var my_buff_data: BuffData

# References to children nodes (Update names to match your Scene Tree exactly)
# Based on your previous script, you had "ICON" and "StackLabel" or "Stack Counter"
@onready var icon_rect = get_node_or_null("ICON")
@onready var stack_label = get_node_or_null("StackLabel")

func setup_slot(data: BuffData, stack_count: int):
	my_buff_data = data
	visible = true

	# Set the Icon
	if icon_rect and data.icon:
		icon_rect.texture = data.icon

	# Set the Stack Count
	if stack_label:
		stack_label.text = str(stack_count)
	elif has_node("Stack Counter"):
		# Fallback for your specific naming if "StackLabel" doesn't exist
		get_node("Stack Counter").text = str(stack_count)

# --- Popup Logic (Connected via Signals in Editor) ---

func _on_mouse_entered():
	if my_buff_data:
		# Calls your Popups system
		# Ensure your Popups script is an Autoload or accessible globally
		# If Popups is a child of the main scene, you might need to find it differently
		# For now, assuming standard access:
		if get_tree().root.has_node("Popups"): # Example check
			get_node("/root/Popups").ItemPopup(get_global_rect(), my_buff_data)
		# Or if you have a Singleton named Popups:
		# Popups.ItemPopup(get_global_rect(), my_buff_data)

func _on_mouse_exited():
	Popups.HideItemPopup()
