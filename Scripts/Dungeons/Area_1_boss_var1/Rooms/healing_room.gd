extends Node2D

enum RoomType { SMALL, MEDIUM, BOSS, HEALING }

@export var room_type: RoomType = RoomType.HEALING
var is_cleared: bool = false
var is_ready_to_clear: bool = false

# Dictionary to store connected rooms: "direction" : room_node
var connected_rooms: Dictionary = {}
var enter_marker: Marker2D
var exit_markers: Dictionary = {}  # "direction" : marker_node

signal room_started
signal room_cleared

@onready var camera_area: Area2D = $CameraArea
@onready var healing_container: Node2D = $HealingContainer
@onready var target_container: Node2D = $TargetContainer
@onready var barrier_on: TileMapLayer = get_node_or_null("Node/Barrier_On")
@onready var barrier_off: TileMapLayer = get_node_or_null("Node/Barrier_Off")

# Goddess statue system
var GoddessStatueScene = preload("res://scenes/godess_statue.tscn")
var goddess_instance = null
var has_been_used: bool = false

func _ready() -> void:
	# Find markers
	if barrier_off:
		barrier_off.visible = true

	for child in get_children():
		if child is Marker2D:
			exit_markers[child.name.to_lower()] = child

	enter_marker = get_node_or_null("Enter")  # If exists
	# Connect signals (check if not already connected to avoid duplicates)
	if not camera_area.body_entered.is_connected(_on_camera_area_body_entered):
		camera_area.body_entered.connect(_on_camera_area_body_entered)
	if not camera_area.body_exited.is_connected(_on_camera_area_body_exited):
		camera_area.body_exited.connect(_on_camera_area_body_exited)

	# Healing room is always cleared (no enemies to fight)
	is_cleared = true

	# Spawn goddess statue immediately when scene loads (before room transitions)
	_spawn_goddess_statue()

func set_connected_room(direction: String, room_node: Node2D):
	connected_rooms[direction] = room_node

func get_connected_room(direction: String) -> Node2D:
	return connected_rooms.get(direction, null)

func start_room():
	room_started.emit(self)
	print("Room " + name + " started")

	# Spawn goddess statue when room starts (so it's visible before player enters camera area)
	_spawn_goddess_statue()

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
		_spawn_goddess_statue()
		print("Player entered room: " + name)

func _spawn_goddess_statue():
	"""Spawn the goddess statue if not already spawned"""
	if goddess_instance != null:
		# Statue already exists - reset it if it has been used
		if has_been_used:
			goddess_instance.set_prompt("")  # Clear prompt for used statue
		else:
			goddess_instance.set_prompt("Heal")  # Reset prompt for available statue
		return  # Don't spawn new one

	goddess_instance = GoddessStatueScene.instantiate()
	healing_container.add_child(goddess_instance)
	goddess_instance.position = Vector2.ZERO  # Position within container

	# Set healing prompt
	goddess_instance.set_prompt("Heal")

	print("Spawned goddess statue in healing room")

	# Connect to goddess activated signal
	if not goddess_instance.is_connected("goddess_activated", _on_goddess_activated):
		goddess_instance.connect("goddess_activated", _on_goddess_activated)

	# Make the goddess findable by the typing system
	call_deferred("_register_goddess_with_typing_system", goddess_instance)

func _register_goddess_with_typing_system(goddess):
	"""Ensure the goddess can be found by the typing system"""
	# Find the main Game node that contains the typing system
	var game = get_tree().root.get_node_or_null("Main/Game")
	if game:
		# Add goddess to game's target container for typing detection
		game.get_node("TargetContainer").add_child(goddess)
		goddess.position = self.global_position
		print("Goddess registered with typing system")
	else:
		print("WARNING: Could not find Game node for goddess registration!")

func _on_goddess_activated():
	"""Called when goddess statue is activated through typing"""
	print("Goddess activated! Player healing initiated.")

	# Check if the goddess statue has already been used
	if has_been_used:
		print("Goddess statue already used - ignoring duplicate activation.")
		return

	# Mark as used immediately to prevent race conditions
	has_been_used = true

	# Heal the player using global function
	Global.heal_damage(1)  # Heal 1 heart

	# Play the healing animation (already handled by goddess statue)
	goddess_instance.play_heal_animation()

	# Clear the prompt after healing
	goddess_instance.set_prompt("")

	print("Player healed! Goddess statue used once.")

	# The goddess will return to idle animation automatically
	# and the prompt is cleared, preventing further use

func _on_camera_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		print("Player exited room: " + name)
