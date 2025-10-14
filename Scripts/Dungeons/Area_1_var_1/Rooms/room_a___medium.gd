extends Node2D

enum RoomType { SMALL, MEDIUM, BOSS }

@export var room_type: RoomType = RoomType.MEDIUM
var is_cleared: bool = false
var is_ready_to_clear: bool = false

# Dictionary to store connected rooms: "direction" : room_node
var connected_rooms: Dictionary = {}
var enter_marker: Marker2D
var exit_markers: Dictionary = {}  # "direction" : marker_node

signal room_started
signal room_cleared

# Enemy spawning
var EnemyScene = preload("res://scenes/Orc_enemy.tscn")
var TargetScene = preload("res://scenes/target.tscn")
var current_category = "medium"  # Can be: easy, medium, hard, typo, sentence, casing
var enemies_spawned = 0  # How many we've actually spawned
var max_enemies_to_spawn = 0  # How many we plan to spawn
var enemies_remaining = 0  # How many are still alive
var available_spawn_points = []
var is_spawning_enemies = false  # True when enemies are still spawning
@onready var spawn_timer: Timer = Timer.new()
@onready var barrier: TileMapLayer = get_tree().get_root().get_node("Dungeon/Node/Barrier")

@onready var camera_area: Area2D = $CameraArea
@onready var enemy_container: Node2D = $EnemyContainer
@onready var target_container: Node2D = $TargetContainer

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

func set_connected_room(direction: String, room_node: Node2D):
	connected_rooms[direction] = room_node

func get_connected_room(direction: String) -> Node2D:
	return connected_rooms.get(direction, null)

func start_room():
	room_started.emit(self)
	print("Room " + name + " started")
	barrier.visible = true

	# Handle camera positioning when entering the room
	_handle_camera_on_room_enter()

	# Only spawn if room is not cleared and not already in progress
	if is_cleared:
		print("Room " + name + " is already cleared, skipping spawning")
		return
 
	if spawn_timer and spawn_timer.time_left > 0 and enemies_spawned > 0:
		print("Room " + name + " is already in progress, skipping spawning")
		return

	# Determine enemy count based on room type
	max_enemies_to_spawn = 1 if room_type == RoomType.MEDIUM else 1

	# Spawn enemies and target
	_spawn_room_enemies(max_enemies_to_spawn)

func clear_room():
	is_cleared = true

	# Remove instantiated target after clearing
	if target_container.get_child_count() > 0:
		var target_instance = target_container.get_child(0)
		target_container.remove_child(target_instance)
		target_instance.queue_free()

	# Stop enemy spawn timer to prevent additional enemies after room clears
	if spawn_timer and spawn_timer.is_inside_tree():
		spawn_timer.stop()

	# Give camera back to player when room is cleared
	_handle_camera_on_room_clear()

	room_cleared.emit(self)
	print("Room " + name + " cleared")
	barrier.visible = false

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

func _spawn_room_enemies(max_enemies: int):
	"""Spawn enemies at spawn points and the target"""
	is_spawning_enemies = true

	# First spawn the target
	_spawn_target()

	# Find spawn points
	var spawn_locations = get_node_or_null("MediumRoomSpawn/SpawnLocations")
	if not spawn_locations:
		spawn_locations = get_node_or_null("SmallRoomSpawn/SpawnLocations")
	if not spawn_locations:
		print("No spawn locations found in room: " + name)
		is_spawning_enemies = false
		return

	# Get all available spawn points
	available_spawn_points = []
	for child in spawn_locations.get_children():
		if child.name.begins_with("SpawnPoint"):
			available_spawn_points.append(child)

	if available_spawn_points.is_empty():
		print("No spawn points found in room: " + name)
		is_spawning_enemies = false
		return

	# Set up timer for spawning enemies one by one every 3 seconds
	add_child(spawn_timer)
	spawn_timer.wait_time = 3.0
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_spawn_next_enemy)
	spawn_timer.start()

	# Record max enemies for this room
	max_enemies_to_spawn = min(max_enemies, available_spawn_points.size())
	enemies_spawned = 0
	enemies_remaining = 0

	print("Starting enemy spawn sequence in room: " + name + " (will spawn " + str(max_enemies_to_spawn) + " enemies)")

func _spawn_target():
	"""Spawn the target at the target container"""
	var target_instance = TargetScene.instantiate()
	target_container.add_child(target_instance)
	target_instance.position = Vector2.ZERO  # Position within container
	target_instance.z_index = 1
	print("Spawned target in room: " + name)

func _spawn_next_enemy():
	"""Spawn the next enemy at a random available spawn point"""
	if enemies_spawned >= max_enemies_to_spawn:
		spawn_timer.stop()
		is_spawning_enemies = false
		print("Enemy spawn sequence complete in room: " + name)
		if enemies_remaining <= 0:
			is_ready_to_clear = true
		return

	if available_spawn_points.is_empty():
		spawn_timer.stop()
		is_spawning_enemies = false
		print("No available spawn points left in room: " + name)
		if enemies_remaining <= 0:
			is_ready_to_clear = true
		return

	# Pick a random spawn point
	var random_index = randi() % available_spawn_points.size()
	var spawn_point = available_spawn_points[random_index]

	_spawn_enemy_at_position(spawn_point.position)
	enemies_spawned += 1
	enemies_remaining += 1

	print("Spawned enemy " + str(enemies_spawned) + "/" + str(max_enemies_to_spawn) + " in room: " + name)

func _spawn_enemy_at_position(spawn_position: Vector2):
	"""Spawn a single enemy at the given position"""
	await get_tree().process_frame

	# Get a word for the enemy
	var selected_word = _get_unique_word()
	if selected_word == "":
		return

	# Create enemy instance
	var enemy_instance = EnemyScene.instantiate()
	enemy_instance.z_index = 3
	enemy_instance.position = spawn_position

	# Set target position (where the target is located)
	var target_position = Vector2.ZERO  # Center, since target is at target_container.position
	if target_container.get_child_count() > 0:
		var target_instance = target_container.get_child(0)
		target_position = target_instance.global_position

	print("New enemy spawned at:", spawn_position)
	print("Moving towards target at:", target_position)
	print("Assigned word: ", selected_word)

	# Add to enemy container
	enemy_container.add_child(enemy_instance)

	# Set the word/prompt for this enemy
	enemy_instance.set_prompt(selected_word)

	# Set enemy target (target position)
	enemy_instance.set_target_position(target_position)

	# Connect enemy death signal to check for room completion
	enemy_instance.tree_exited.connect(_on_enemy_died)

func _get_unique_word() -> String:
	"""Get a unique word for the enemy"""
	if not WordDatabase:
		print("WordDatabase not loaded!")
		return "enemy"

	var available_words = WordDatabase.get_category_words(current_category)
	if available_words.is_empty():
		print("No words available in category: " + current_category)
		return "enemy"

	# Pick random word
	return available_words[randi() % available_words.size()]

func _on_enemy_died():
	"""Called when an enemy dies - check if room is ready to be cleared"""
	enemies_remaining -= 1
	if enemies_remaining <= 0 and not is_spawning_enemies:
		is_ready_to_clear = true

func _handle_camera_on_room_enter():
	"""Move camera to this room if it's uncleared (combat room)"""
	if is_cleared:
		# Room is already cleared, camera should follow player
		return

	# Move camera from player to this room (center the camera on the room)
	var player = get_node("../Player")
	if player and player.get_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		player.remove_child(camera)
		add_child(camera)

		# Set camera position to center of the room
		var room_center = Vector2.ZERO  # Room center relative to room node
		camera.position = room_center

		print("Camera moved to room center for combat: " + name)

func _handle_camera_on_room_clear():
	"""Move camera back to player when room is cleared"""
	if not is_cleared:
		return

	var player = get_node("../Player")
	if player and get_node_or_null("Camera2D"):
		var camera = get_node("Camera2D")
		remove_child(camera)
		player.add_child(camera)
		camera.position = Vector2.ZERO  # Reset camera position relative to player

		print("Camera returned to player after clearing room: " + name)
