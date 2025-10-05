extends Node2D

signal room_started
signal room_cleared

@export var small_spawn_scene: PackedScene
@export var medium_spawn_scene: PackedScene
@export var adjacent_rooms: Dictionary[String, NodePath]
@export var room_type: String = ""
var room_bounds: Rect2 = Rect2()
var cleared: bool = false

func _ready() -> void:
	if room_type == "":
		if " - " in name:
			room_type = name.split(" - ")[1]
		else:
			room_type = name

	var bounds_node = get_node("CameraArea/CollisionShape2D")
	if bounds_node and bounds_node.shape is RectangleShape2D:
		var shape = bounds_node.shape as RectangleShape2D
		room_bounds = Rect2(bounds_node.global_position - shape.extents, shape.extents * 2)

func get_exit_marker(direction: String) -> Node2D:
	var hallway_name = "Hallway" + direction.capitalize()
	var hallway = get_node(hallway_name)
	if hallway:
		return hallway
	else:
		return null

func start_room() -> void:
	# Disabled spawning for now, focus on room transition
	pass

func _on_spawn_finished() -> void:
	set_cleared()

func set_cleared() -> void:
	cleared = true
	emit_signal("room_cleared")
	_enable_hallway_directions()

func _enable_hallway_directions():
	for child in get_children():
		if child.name.begins_with("Hallway") and child.has_method("set_prompt"):
			var direction = child.name.substr(7).to_lower().capitalize()
			child.set_prompt(direction)
