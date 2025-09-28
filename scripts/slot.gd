extends PanelContainer

@export var title: String = ""
@export var description: String = ""
@export var icon: Texture2D

signal slot_selected(slot)

func _ready() -> void:
	# Initialize icon if provided
	var icon_node := get_node_or_null("ICON")
	if icon_node and icon is Texture2D:
		icon_node.texture = icon

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("slot_selected", self)

func get_item() -> Dictionary:
	return {
		"title": title,
		"description": description,
		"icon": icon
	}
