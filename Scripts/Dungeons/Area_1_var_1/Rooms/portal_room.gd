extends Node2D

enum RoomType { SMALL, MEDIUM, BOSS }

@export var room_type: RoomType = RoomType.BOSS
var is_cleared: bool = false
var is_ready_to_clear: bool = false

# Dictionary to store connected rooms: "direction" : room_node
var connected_rooms: Dictionary = {}
var enter_marker: Marker2D
var exit_markers: Dictionary = {}  # "direction" : marker_node

signal room_started
signal room_cleared

@onready var camera_area: Area2D = $CameraArea
@onready var portal_container: Node2D = $PortalContainer
var GreenPortalScene = preload("res://scenes/GreenPortal.tscn")

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

	# Portal room is always cleared
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
	var player = get_node("/root/Main/Player")
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
		_spawn_portal()
		print("Player entered room: " + name)

func _spawn_portal():
	"""Spawn the portal if not already spawned"""
	if portal_container.get_child_count() > 0: 
		return  # Already has portal

	var portal_instance = GreenPortalScene.instantiate()
	portal_container.add_child(portal_instance)
	portal_instance.position = Vector2.ZERO  # Position within container
	portal_instance.set_prompt("Warp")  # Set typing prompt
	portal_instance.play_appear_animation()  # Play appear animation

	# Connect to portal activated signal
	if not portal_instance.is_connected("portal_activated", _on_portal_activated):
		portal_instance.connect("portal_activated", _on_portal_activated)

	print("Spawned portal in portal room")

	# Make the portal findable by the typing system
	# The typing system looks for portals in the main Game scene
	call_deferred("_register_portal_with_typing_system", portal_instance)

func _register_portal_with_typing_system(portal):
	"""Ensure the portal can be found by the typing system"""
	# Find the main Game node that contains the typing system
	var game = get_tree().root.get_node_or_null("Main/Game")
	if game:
		# Add portal to game's portal container for typing detection
		game.get_node("PortalContainer").add_child(portal)
		portal.position = self.global_position
		print("Portal registered with typing system")
	else:
		print("WARNING: Could not find Game node for portal registration!")

func _on_portal_activated():
	"""Called when portal is activated - this replaces scene change"""
	print("Portal activated! Switching to boss dungeon.")

	# Get reference to MainManager and call dungeon switch immediately
	var main_manager = get_tree().root.get_node_or_null("Main/MainManager")
	if main_manager:
		main_manager.switch_to_boss_dungeon()
	else:
		print("ERROR: Could not find MainManager!")

func _on_camera_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		print("Player exited room: " + name)
