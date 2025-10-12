extends Node2D

enum RoomType { SMALL, MEDIUM, BOSS }

@export var room_type: RoomType = RoomType.SMALL
var is_cleared: bool = false
var is_ready_to_clear: bool = false

# Dictionary to store connected rooms: "direction" : room_node
var connected_rooms: Dictionary = {}
var enter_marker: Marker2D
var exit_markers: Dictionary = {}  # "direction" : marker_node

signal room_started
signal room_cleared

@onready var camera_area: Area2D = $CameraArea

func _ready() -> void:
	# Find markers
	for child in get_children():
		if child is Marker2D:
			exit_markers[child.name.to_lower()] = child

	enter_marker = get_node_or_null("Enter")  # If exists
	# Connect signals (check if not already connected to avoid duplicates)
	if not camera_area.body_entered.is_connected(_on_camera_area_body_entered):
		camera_area.body_entered.connect(_on_camera_area_body_entered)
	if not camera_area.body_exited.is_connected(_on_camera_area_body_exited):
		camera_area.body_exited.connect(_on_camera_area_body_exited)

	# Starting room is always cleared
	is_cleared = true

func set_connected_room(direction: String, room_node: Node2D):
	connected_rooms[direction] = room_node

func get_connected_room(direction: String) -> Node2D:
	return connected_rooms.get(direction, null)

func start_room():
	room_started.emit(self)
	print("Room " + name + " started")

func clear_room():
	is_cleared = true
	room_cleared.emit(self)
	print("Room " + name + " cleared")

func update_camera():
	# Update camera based on room
	# Assuming Camera2D is attached to player
	var player = get_node("../Player")
	if player and player.get_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		var shape = camera_area.get_node("CollisionShape2D")
		var view_size = get_viewport_rect().size
		var size = shape.shape.extents*2
		if size.y <view_size.y:
			size.y = view_size.y

		if size.x < view_size.y:
			size.x = view_size.y

		if shape is RectangleShape2D:
			var rect = shape.get_rect()
			var center = camera_area.global_position - rect.get_center()
			camera.limit_left = center.x - rect.size.x / 2
			camera.limit_right = center.x + rect.size.x / 2
			camera.limit_top = center.y - rect.size.y / 2
			camera.limit_bottom = center.y + rect.size.y / 2

func _on_camera_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		update_camera()
		print("Player entered room: " + name)

func _on_camera_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		print("Player exited room: " + name)
