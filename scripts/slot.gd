extends PanelContainer

const EnemyData = preload("res://Scripts/EnemyData.gd")

@export var enemy_data: EnemyData

signal slot_selected(enemy_data: EnemyData)

func _ready() -> void:
	# Initialize icon if enemy_data provided
	var icon_node := get_node_or_null("ICON")
	if icon_node and enemy_data and enemy_data.static_sprite:
		icon_node.texture = enemy_data.static_sprite
		icon_node.visible = true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if enemy_data:
			emit_signal("slot_selected", enemy_data)

func get_enemy_data() -> EnemyData:
	return enemy_data

func get_item() -> Dictionary:
	if enemy_data:
		return {
			"name": enemy_data.name,
			"description": enemy_data.description,
			"static_sprite": enemy_data.static_sprite
		}
	return {}
