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

# Enemy spawning
@export var enemy_waves: Array[EnemyWave] = []
var TargetScene = preload("res://scenes/target.tscn")
var MinotaurScene = preload("res://Scenes/Boss/Minotaur.tscn")
var current_category = "medium"  # Can be: easy, medium, hard, typo, sentence, casing
var enemies_spawned = 0  # How many we've actually spawned
var max_enemies_to_spawn = 0  # How many we plan to spawn
var enemies_remaining = 0  # How many are still alive
var available_spawn_points = []
var is_spawning_enemies = false  # True when enemies are still spawning
var boss_spawned = false  # Track if boss has been spawned
var current_wave_index = 0  # Current wave being spawned
var current_wave_spawned = 0  # Enemies spawned in current wave
@onready var spawn_timer: Timer = Timer.new()
@onready var wave_delay_timer: Timer = Timer.new()

@onready var camera_area: Area2D = $CameraArea
@onready var enemy_container: Node2D = $EnemyContainer
@onready var target_container: Node2D = $TargetContainer
@onready var barrier_on: TileMapLayer = get_node_or_null("../Node/Barrier_On")
@onready var barrier_off: TileMapLayer = get_node_or_null("../Node/Barrier_Off")
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

func set_connected_room(direction: String, room_node: Node2D):
	connected_rooms[direction] = room_node

func get_connected_room(direction: String) -> Node2D:
	return connected_rooms.get(direction, null)

func start_room():
	room_started.emit(self)
	print("Room " + name + " started")
	barrier_on.visible = true
	barrier_off.visible = false

	# Handle camera positioning when entering the room
	_handle_camera_on_room_enter()

	# Only spawn if room is not cleared and not already in progress
	if is_cleared:
		print("Room " + name + " is already cleared, skipping spawning")
		barrier_on.visible = false
		barrier_off.visible = true
		return

	if spawn_timer and spawn_timer.time_left > 0 and enemies_spawned > 0:
		print("Room " + name + " is already in progress, skipping spawning")
		return

	# Calculate total enemies from all waves
	max_enemies_to_spawn = 0
	for wave in enemy_waves:
		max_enemies_to_spawn += wave.count

	if max_enemies_to_spawn == 0:
		print("No enemies configured for room: " + name)
		is_ready_to_clear = true
		return

	# Spawn enemies and target
	_spawn_room_enemies()

func clear_room():
	is_cleared = true
	barrier_on.visible = false
	barrier_off.visible = true

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

	# Spawn portal after boss room is cleared
	_spawn_portal()

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
		print("Player entered room: " + name)

func _on_camera_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		print("Player exited room: " + name)

func _spawn_room_enemies():
	"""Spawn enemies in waves at spawn points and the target"""
	is_spawning_enemies = true

	# First spawn the target
	_spawn_target()

	# Find spawn points
	var spawn_locations = get_node_or_null("MediumRoomSpawn/SpawnLocations")
	if not spawn_locations:
		spawn_locations = get_node_or_null("SmallRoomSpawn/SpawnLocations")
	if not spawn_locations:
		spawn_locations = get_node_or_null("BossRoomSpawn/SpawnLocations")
	if not spawn_locations:
		print("No spawn locations found in room: " + name)
		is_spawning_enemies = false
		return

	# Get all available spawn points
	available_spawn_points = []
	for child in spawn_locations.get_children():
		# Add direct spawn points
		if child.name.begins_with("SpawnPoint") or child.name.begins_with("Bottom") or child.name.begins_with("Top") or child.name.ends_with("Point"):
			available_spawn_points.append(child)
		# Add children from cardinal direction groups (North, South, East, West)
		if child.name in ["North", "South", "East", "West"]:
			for grandchild in child.get_children():
				if grandchild.name.begins_with("SpawnPoint"):
					available_spawn_points.append(grandchild)

	if available_spawn_points.is_empty():
		print("No spawn points found in room: " + name)
		is_spawning_enemies = false
		return

	# Initialize wave spawning
	current_wave_index = 0
	enemies_spawned = 0
	enemies_remaining = 0

	# Set up timers
	add_child(spawn_timer)
	add_child(wave_delay_timer)

	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_spawn_next_enemy_in_wave)

	wave_delay_timer.one_shot = true
	wave_delay_timer.timeout.connect(_start_next_wave)

	# Start first wave
	_start_next_wave()

	print("Starting wave-based enemy spawn sequence in room: " + name + " (" + str(enemy_waves.size()) + " waves, " + str(max_enemies_to_spawn) + " total enemies)")

func _spawn_target():
	"""Spawn the target at the target container"""
	var target_instance = TargetScene.instantiate()
	target_container.add_child(target_instance)
	target_instance.position = Vector2.ZERO  # Position within container
	print("Spawned target in room: " + name)

func _start_next_wave():
	"""Start spawning the next wave of enemies"""
	if current_wave_index >= enemy_waves.size():
		# All waves complete
		is_spawning_enemies = false
		print("All waves complete in room: " + name)
		if enemies_remaining <= 0:
			is_ready_to_clear = true
		return

	var current_wave = enemy_waves[current_wave_index]
	current_wave_spawned = 0

	print("Starting wave " + str(current_wave_index + 1) + "/" + str(enemy_waves.size()) + " in room: " + name + " (" + str(current_wave.count) + " enemies)")

	# Start spawning enemies in this wave
	spawn_timer.wait_time = current_wave.spawn_delay
	spawn_timer.start()

func _spawn_next_enemy_in_wave():
	"""Spawn the next enemy in the current wave"""
	if current_wave_index >= enemy_waves.size():
		spawn_timer.stop()
		return

	var current_wave = enemy_waves[current_wave_index]

	if current_wave_spawned >= current_wave.count:
		# Current wave complete, move to next wave
		spawn_timer.stop()
		current_wave_index += 1

		if current_wave.wave_delay > 0:
			# Wait before starting next wave
			wave_delay_timer.wait_time = current_wave.wave_delay
			wave_delay_timer.start()
		else:
			# Start next wave immediately
			_start_next_wave()
		return

	if available_spawn_points.is_empty():
		print("No available spawn points left in room: " + name)
		spawn_timer.stop()
		return

	# Pick a random spawn point
	var random_index = randi() % available_spawn_points.size()
	var spawn_point = available_spawn_points[random_index]

	_spawn_enemy_at_position(spawn_point.position, current_wave.enemy_scene)
	enemies_spawned += 1
	enemies_remaining += 1
	current_wave_spawned += 1

	print("Spawned enemy " + str(current_wave_spawned) + "/" + str(current_wave.count) + " in wave " + str(current_wave_index + 1) + " (total: " + str(enemies_spawned) + "/" + str(max_enemies_to_spawn) + ") in room: " + name)

func _spawn_enemy_at_position(spawn_position: Vector2, enemy_scene: PackedScene):
	"""Spawn a single enemy at the given position"""
	await get_tree().process_frame

	# Check if this is a boss enemy - if so, try to use specific boss spawn point
	var is_boss_enemy = false
	if enemy_scene:
		var temp_instance = enemy_scene.instantiate()
		is_boss_enemy = temp_instance.get("max_boss_health") != null
		temp_instance.queue_free()

	var final_spawn_position = spawn_position
	if is_boss_enemy:
		# Find specific boss spawn point
		var spawn_locations = get_node_or_null("BossRoomSpawn/SpawnLocations")
		var boss_spawn_point = null

		if spawn_locations:
			for child in spawn_locations.get_children():
				if child.name == "BossSpawnPoint":
					boss_spawn_point = child
					break
				if child.name in ["North", "South", "East", "West"]:
					for grandchild in child.get_children():
						if grandchild.name == "BossSpawnPoint":
							boss_spawn_point = grandchild
							break
					if boss_spawn_point:
						break

		if boss_spawn_point:
			final_spawn_position = boss_spawn_point.position
			print("Boss enemy detected - using specific spawn point: " + boss_spawn_point.name)
		else:
			print("Boss enemy detected but no BossSpawnPoint found - using assigned position")

	# Get a word for the enemy (skip for bosses - they get words through targeting phases)
	var selected_word = ""
	if not is_boss_enemy:
		selected_word = _get_unique_word()
		if selected_word == "":
			return

	# Create enemy instance
	var enemy_instance = enemy_scene.instantiate()
	enemy_instance.z_index = 3
	enemy_instance.position = final_spawn_position

	# Set target position (where the target is located)
	var target_position = Vector2.ZERO  # Center, since target is at target_container.position
	if target_container.get_child_count() > 0:
		var target_instance = target_container.get_child(0)
		target_position = target_instance.global_position

	print("New enemy spawned at:", spawn_position)
	print("Moving towards target at:", target_position)
	if not is_boss_enemy:
		print("Assigned word: ", selected_word)
	else:
		print("Boss enemy spawned - word will be assigned through targeting phases")

	# Add to enemy container
	enemy_container.add_child(enemy_instance)

	# Set the word/prompt for this enemy (empty for bosses)
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

	# Check if room is ready to clear:
	# - All enemies must be dead (enemies_remaining <= 0)
	# - Not currently spawning new enemies (is_spawning_enemies == false)
	if enemies_remaining <= 0 and not is_spawning_enemies:
		is_ready_to_clear = true
		print("Room ready to clear: All enemies defeated!")
	else:
		print("Room not yet ready to clear: enemies_remaining=", enemies_remaining, " is_spawning=", is_spawning_enemies)

func _handle_camera_on_room_enter():
	"""Move camera to this room if it's uncleared (combat room)"""
	if is_cleared:
		# Room is already cleared, camera should follow player
		return

	# Move camera from player to this room (center the camera on the room)
	var player = get_node("/root/Main/Player")
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

	var player = get_node("/root/Main/Player")
	if player and get_node_or_null("Camera2D"):
		var camera = get_node("Camera2D")
		remove_child(camera)
		player.add_child(camera)
		camera.position = Vector2.ZERO  # Reset camera position relative to player

		print("Camera returned to player after clearing room: " + name)

func has_boss_spawned() -> bool:
	"""Check if the minotaur boss has been spawned"""
	return boss_spawned

func _spawn_boss():
	"""Spawn the Minotaur boss at a spawn location (separate from regular enemy count)"""
	if boss_spawned:
		return

	await get_tree().create_timer(1.0).timeout  # Brief delay before boss spawn

	# Find available spawn points (same as regular enemies)
	var spawn_locations = get_node_or_null("BossRoomSpawn/SpawnLocations")
	var available_spawn_points_for_boss = []
	var boss_spawn_point = null

	if spawn_locations:
		for child in spawn_locations.get_children():
			# Check for specific boss spawn point first
			if child.name == "BossSpawnPoint":
				boss_spawn_point = child
				break
			# Add direct spawn points
			if child.name.begins_with("SpawnPoint") or child.name.begins_with("Bottom") or child.name.begins_with("Top") or child.name.ends_with("Point"):
				available_spawn_points_for_boss.append(child)
			# Add children from cardinal direction groups (North, South, East, West)
			if child.name in ["North", "South", "East", "West"]:
				for grandchild in child.get_children():
					if grandchild.name == "BossSpawnPoint":
						boss_spawn_point = grandchild
						break
					if grandchild.name.begins_with("SpawnPoint"):
						available_spawn_points_for_boss.append(grandchild)

	# Use specific boss spawn point if found, otherwise pick random
	var spawn_point
	if boss_spawn_point:
		spawn_point = boss_spawn_point
		print("Using specific boss spawn point: " + boss_spawn_point.name)
	else:
		if available_spawn_points_for_boss.is_empty():
			print("No spawn locations found for boss! Spawning at center.")
			available_spawn_points_for_boss = [Node2D.new()]  # Fallback to center
			available_spawn_points_for_boss[0].position = Vector2.ZERO

		# Pick a random spawn point for the boss
		var random_index = randi() % available_spawn_points_for_boss.size()
		spawn_point = available_spawn_points_for_boss[random_index]
		print("Using random spawn point for boss: " + spawn_point.name if spawn_point.has_method("get") else "center")

	# Create Minotaur instance
	var boss_instance = MinotaurScene.instantiate()
	boss_instance.z_index = 3

	# Spawn at the selected spawn location
	boss_instance.position = spawn_point.position

	# Set target position (where the target is located)
	var target_position = Vector2.ZERO  # Center, since target is at target_container.position
	if target_container.get_child_count() > 0:
		var target_instance = target_container.get_child(0)
		target_position = target_instance.global_position

	print("Summoning MINOTAUR BOSS at:", spawn_point.position, "(spawn point:", spawn_point.name if spawn_point.has_method("get") else "center", ")")
	print("Moving towards target at:", target_position)

	# Add to enemy container (so input selection works)
	enemy_container.add_child(boss_instance)

	# Set a boss-level word for the minotaur
	var boss_word = _get_unique_word()
	if boss_word == "":
		boss_word = "MINOTAUR"  # Fallback boss word
	boss_instance.set_prompt(boss_word)

	# Set boss target position
	boss_instance.set_target_position(target_position)

	# Connect boss death signal to track room completion
	boss_instance.tree_exited.connect(_on_enemy_died)

	boss_spawned = true
	print("MINOTAUR BOSS SPAWNED - Fight for your life!")

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

	print("Spawned portal in boss room")

func _on_portal_activated():
	"""Called when portal is activated - trigger boss dungeon completion"""
	print("Portal activated! Completing boss dungeon.")

	# Get reference to MainManager and call boss dungeon cleared
	var main_manager = get_tree().root.get_node_or_null("Main/MainManager")
	if main_manager:
		main_manager.boss_dungeon_cleared()
	else:
		print("ERROR: Could not find MainManager!")
