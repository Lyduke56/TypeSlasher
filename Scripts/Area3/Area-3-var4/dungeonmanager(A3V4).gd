extends Node2D

var current_room: Node2D
var rooms: Array[Node2D] = []
var player: CharacterBody2D
var is_transitioning: bool = false
var block_all_input: bool = false  # Block all input during transitions

@onready var direction_label: RichTextLabel = $"/root/Main/Hud/Direction"

var tween: Tween

# Typing mechanics variables (similar to game.gd)
var active_enemy = null
var current_letter_index: int = -1
var is_processing_completion: bool = false
var input_buffer: Array[String] = []

# Signal for prompt update
signal prompt_updated(full_text: String, current_index: int)
signal prompt_cleared

func _ready() -> void:
	# Connect to health changes first, before any health modifications
	Global.player_health_changed.connect(_on_health_changed)

	# Health persists across dungeons - clamp current health to ensure it's within valid range
	Global.player_current_health = clamp(Global.player_current_health, 0, Global.player_max_health)

	# Create heart container, score label, and active buffs display immediately
	setup_heart_container()
	setup_score_label()
	setup_active_buffs()

	# Wait for target to apply health buffs, then update heart container
	await get_tree().process_frame
	Global.player_health_changed.emit(Global.player_current_health, Global.player_max_health)

	set_process_input(true)
	set_process_unhandled_input(true)

	# Find all rooms in the scene
	for child in get_parent().get_children():
		if child.has_method("start_room"): # safer room detection
			rooms.append(child)

	# Set connections manually for now (can be exported later)
	setup_room_connections()

	# Find player (now in Main scene, not dungeon scene)
	player = get_node("/root/Main/Player")

	# Make player's camera current for UI rendering
	if player.has_node("Camera2D"):
		player.get_node("Camera2D").make_current()

	# Connect player signals to handle enemy destruction
	player.enemy_reached.connect(_on_enemy_reached)
	player.slash_completed.connect(_on_player_slash_completed)
	player.player_returned.connect(_on_player_returned)

	# Start in the starting room
	current_room = get_node("../StartingRoom")
	current_room.start_room()
	show_directions()

	# Set player center position to starting room position
	var start_enter_marker = current_room.enter_marker if current_room.enter_marker else current_room.global_position
	player.center_position = start_enter_marker

	# Connect signals from rooms
	for room in rooms:
		room.room_cleared.connect(_on_room_cleared)
		room.room_started.connect(_on_room_started)

func _process(_delta):
	# Process input buffer one character per frame for high WPM handling
	# Cached: Moved update_score to only when actual progress is made
	if not input_buffer.is_empty() and not is_processing_completion:
		var key_typed = input_buffer.pop_front()
		_process_single_character(key_typed)


# ------------------------------------------------------------
# ROOM CONNECTION SETUP
# ------------------------------------------------------------
func setup_room_connections():
	var starting = get_node("../StartingRoom")
	var room_a = get_node("../RoomA - Medium")
	var room_b = get_node("../RoomB - Medium")
	var room_c = get_node("../RoomC - Medium")
	var room_d = get_node("../RoomD - Medium")
	var portal = get_node("../PortalRoom")
	var healing = get_node("../HealingRoom")

	starting.set_connected_room("top", room_b)
	starting.set_connected_room("bottom", room_d)
	starting.set_connected_room("right", room_a)
	starting.set_connected_room("left", room_c)

	room_a.set_connected_room("left", starting)
	room_a.set_connected_room("bottom", portal)

	room_b.set_connected_room("bottom", starting)

	room_c.set_connected_room("right", starting)
	room_c.set_connected_room("bottom", healing)

	room_d.set_connected_room("top", starting)

	portal.set_connected_room("top", room_a)

	healing.set_connected_room("top", room_c)

# ------------------------------------------------------------
# DIRECTION PROMPT
# ------------------------------------------------------------
func show_directions():
	if direction_label and current_room != null:
		if current_room.is_cleared:
			var directions = current_room.exit_markers.keys()
			direction_label.text = "Type direction: " + ", ".join(directions)
			direction_label.visible = true
		else:
			direction_label.visible = false


# ------------------------------------------------------------
# INPUT HANDLING (Arrow Keys)
# ------------------------------------------------------------
func _input(event):
	# Block ALL input during room transitions
	if block_all_input:
		return

	# Block movement during enemy processing, word completion, or enemy spawning
	# Block movement if player can't move (before spawn animation)
	if Global.player_can_move == false:
		return

	# Skip blocking for starting room, portal room, idle room, and healing room (they don't spawn enemies)
	var skip_blocking = current_room != null and (current_room.name == "StartingRoom" or current_room.name == "PortalRoom" or current_room.name == "IdleRoom" or current_room.name == "HealingRoom")
	if not skip_blocking and (active_enemy != null or is_processing_completion or (current_room != null and current_room.has_method("get") and current_room.get("is_spawning_enemies") == true)):
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var direction = ""
		match event.keycode:
			KEY_UP:
				direction = "top"
			KEY_DOWN:
				direction = "bottom"
			KEY_LEFT:
				direction = "left"
			KEY_RIGHT:
				direction = "right"

		if direction != "" and current_room != null and current_room.exit_markers.has(direction) and not self.is_transitioning:
			# Only allow transition if current room is cleared (skip check for starting/portal rooms)
			if not skip_blocking and not current_room.is_cleared:
				print("Cannot transition - current room is not cleared yet")
				return
			transition_to_room(direction)


# ------------------------------------------------------------
# ROOM TRANSITIONS
# ------------------------------------------------------------
func transition_to_room(direction: String):
	if current_room == null:
		return

	var next_room = current_room.get_connected_room(direction)
	if not next_room:
		return

	print("Transitioning from %s to %s via %s" %
		[current_room.name, next_room.name, direction])

	# Block ALL input during transition
	block_all_input = true

	# Kill existing tween if any
	if tween and tween.is_running():
		tween.kill()

	# Find exit marker in current room
	var exit_marker = current_room.exit_markers.get(direction)
	if not exit_marker:
		print("No exit marker for direction: " + direction)
		return

	# Find opposite direction marker in next room
	var opposite = ""
	match direction:
		"top": opposite = "bottom"
		"bottom": opposite = "top"
		"left": opposite = "right"
		"right": opposite = "left"

	var enter_marker = next_room.exit_markers.get(opposite)
	if not enter_marker:
		enter_marker = next_room.global_position

	# Check for TargetContainer in the new room (or PortalContainer for portal rooms)
	var center_marker = next_room.get_node_or_null("TargetContainer")
	if center_marker == null:
		center_marker = next_room.get_node_or_null("PortalContainer")
	var final_position = center_marker.global_position if center_marker else (enter_marker.global_position if enter_marker is Marker2D else enter_marker)

	self.is_transitioning = true

	# Disable player input and physics during tween
	player.set_process_input(false)
	player.set_physics_process(false)

	player.anim.play("run")
	# Set initial direction for first tween
	var initial_dir = (exit_marker.global_position - player.global_position).normalized()
	if initial_dir.x != 0:
		player.anim.flip_h = initial_dir.x < 0

	tween = create_tween()

	tween.tween_property(player, "global_position", exit_marker.global_position, 0.8).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		# Update direction for second tween
		var second_dir = (final_position - player.global_position).normalized()
		if second_dir.x != 0:
			player.anim.flip_h = second_dir.x < 0
	)
	tween.tween_property(player, "global_position", final_position, 1.5).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		player.anim.play("idle")
		input_buffer.clear()
		active_enemy = null
		current_letter_index = -1
		prompt_cleared.emit()

			# Switch to new room (no camera management needed - handled by room start)
		current_room = next_room
		next_room.start_room()
		show_directions()

		# Adjust camera to room size based on CameraArea's CollisionShape2D by zooming to fit
		var camera = get_viewport().get_camera_2d()
		if camera:
			var camera_area = current_room.get_node_or_null("CameraArea")
			if camera_area:
				var collision_shape = camera_area.get_node_or_null("CollisionShape2D")
				if collision_shape and collision_shape.shape is RectangleShape2D:
					var shape = collision_shape.shape as RectangleShape2D
					var viewport_size = get_viewport().get_visible_rect().size
					# Calculate zoom to fit the shape into the viewport
					var zoom_x = viewport_size.x / shape.size.x
					var zoom_y = viewport_size.y / shape.size.y
					var zoom_level = min(zoom_x, zoom_y)  # Use min to fit entirely, or max to cover
					# Actually, since we want to fit the area,zoom_level = max(shape.size.x / viewport_size.x, shape.size.y / viewport_size.y) if we want to zoom out to fit
					# Yes, to ensure the whole shape is visible, zoom out if necessary
					zoom_level = min(viewport_size.x / shape.size.x, viewport_size.y / shape.size.y)
					var target_zoom = Vector2(zoom_level, zoom_level)
					var target_pos = current_room.position + camera_area.position

					# Animate camera zoom and position
					var new_tween = create_tween()
					new_tween.set_trans(Tween.TRANS_SINE)
					new_tween.set_ease(Tween.EASE_IN_OUT)
					new_tween.tween_property(camera, "zoom", target_zoom, 0.5)
					new_tween.tween_property(camera, "global_position", global_position + target_pos, 0.5)
					await new_tween.finished  # Wait for camera animation

					# Reset limits to allow zooming
					camera.limit_left = -1000000
					camera.limit_right = 1000000
					camera.limit_top = -1000000
					camera.limit_bottom = 1000000

		player.center_position = final_position
		player.reset_combo()  # Reset combo with new center
		player.set_physics_process(true)
		player.set_process_input(true)
		self.is_transitioning = false
		block_all_input = false  # Re-enable all input
		print("Transition complete")
	)

# ------------------------------------------------------------
# SIGNAL HANDLERS
# ------------------------------------------------------------
func _on_room_cleared(room):
	if room == current_room:
		show_directions()

func _on_room_started(room):
	if room == current_room:
		pass

	# Ensure goddess statue is spawned when entering healing room
	var healing_container = room.get_node_or_null("HealingContainer")
	if healing_container and room.name == "HealingRoom":
		if healing_container.get_child_count() == 0:
			print("Healing room started - ensuring goddess statue is spawned")
			if room.has_method("_spawn_goddess_statue"):
				room._spawn_goddess_statue()

func _on_player_returned():
	"""Called when player finishes returning to center - check if room can be cleared"""
	if current_room and current_room.is_ready_to_clear and not current_room.is_cleared:
		current_room.clear_room()

# ------------------------------------------------------------
# TYPING MECHANICS (similar to game.gd)
# ------------------------------------------------------------
func find_new_active_enemy(typed_character: String):
	"""Find a new enemy that starts with the typed character"""
	if is_processing_completion:
		return

	# Check the current room's enemy container for targetable enemies
	if current_room and current_room.has_node("EnemyContainer"):
		var enemy_container = current_room.get_node("EnemyContainer")
		for entity in enemy_container.get_children():
			# Skip invalid entities or entities that don't have typing interface
			if not is_instance_valid(entity) or not entity.has_method("get_prompt"):
				continue
			# Skip entities that are already being targeted
			if entity.get("is_being_targeted") == true:
				continue

			var prompt = entity.get_prompt()
			if prompt.length() > 0 and prompt.substr(0, 1).to_lower() == typed_character:
				print("Found new enemy that starts with ", typed_character)
				active_enemy = entity
				current_letter_index = 1
				active_enemy.set_next_character(current_letter_index)
				prompt_updated.emit(prompt, current_letter_index)  # After enemy.set_next_character()
				break

	# Also check for portals in portal rooms
	if current_room and current_room.has_node("PortalContainer") and current_room.name == "PortalRoom":
		var portal_container = current_room.get_node("PortalContainer")
		for entity in portal_container.get_children():
			# Skip invalid entities or entities that don't have typing interface
			if not is_instance_valid(entity) or not entity.has_method("get_prompt"):
				continue
			# Skip entities that are already being targeted
			if entity.get("is_being_targeted") == true:
				continue

			var prompt = entity.get_prompt()
			if prompt.length() > 0 and prompt.substr(0, 1).to_lower() == typed_character:
				print("Found portal that starts with ", typed_character)
				active_enemy = entity
				current_letter_index = 1
				active_enemy.set_next_character(current_letter_index)
				prompt_updated.emit(prompt, current_letter_index)  # After enemy.set_next_character()
				break

	# Also check for goddess statue in healing rooms
	if current_room and current_room.has_node("HealingContainer") and current_room.name == "HealingRoom":
		var healing_container = current_room.get_node("HealingContainer")
		for entity in healing_container.get_children():
			# Skip invalid entities or entities that don't have typing interface
			if not is_instance_valid(entity) or not entity.has_method("get_prompt"):
				continue
			# Skip entities that are already being targeted
			if entity.get("is_being_targeted") == true:
				continue

			var prompt = entity.get_prompt()
			if prompt.length() > 0 and prompt.substr(0, 1).to_lower() == typed_character:
				print("Found goddess statue that starts with ", typed_character)
				active_enemy = entity
				current_letter_index = 1
				active_enemy.set_next_character(current_letter_index)
				prompt_updated.emit(prompt, current_letter_index)  # After enemy.set_next_character()
				break

func _complete_word():
	"""Handle word completion with atomic operation"""
	if is_processing_completion or active_enemy == null or not is_instance_valid(active_enemy):
		return

	# Set processing flag to block all other operations
	is_processing_completion = true

	var entity_position = active_enemy.global_position
	var completed_entity = active_enemy

	print("Word completed! Entity at: ", entity_position)

	# Atomically update all state
	if completed_entity.has_method("set_targeted_state"):
		# Avoid targeting visual on bosses (prevents greying out/stuck state)
		var is_boss = false
		# Detect boss by presence of boss-specific property used in boss script
		if completed_entity != null:
			var boss_max = null
			# Using get() returns null if property doesn't exist
			boss_max = completed_entity.get("max_boss_health")
			is_boss = boss_max != null
		if not is_boss:
			completed_entity.set("is_being_targeted", true)
			completed_entity.set_targeted_state(true)

	active_enemy = null
	current_letter_index = -1

	prompt_cleared.emit()

	# Clear input buffer of any remaining inputs
	input_buffer.clear()

	# Handle different entity types after completion
	if completed_entity.has_method("play_disappear_animation"):
		# Portal completion - do NOT dash to portal, just play disappear animation and notify MainManager
		print("Portal completed! Playing disappear animation and switching to boss dungeon.")
		completed_entity.play_disappear_animation()
		# After portal animation, notify MainManager to handle progression
		var main_manager = get_tree().root.get_node_or_null("Main/MainManager")
		if main_manager and main_manager.has_method("switch_to_boss_dungeon"):
			await get_tree().create_timer(0.5).timeout  # Wait for disappear animation
			main_manager.switch_to_boss_dungeon()
		else:
			print("ERROR: Could not find MainManager or switch_to_boss_dungeon method!")
	elif completed_entity.has_method("play_heal_animation"):
		# Goddess statue completion - do NOT dash to statue, just play heal animation
		# Check if the statue hasn't been used yet to prevent multiple usages
		if completed_entity.has_method("get") and completed_entity.get("has_been_used") != true:
			print("Goddess statue completed! Playing heal animation.")
			completed_entity.play_heal_animation()
		else:
			print("Goddess statue already used - not triggering again.")
	else:
		# Regular enemy completion - dash to and attack
		print("Enemy completed! Player dashing to enemy.")
		player.dash_to_enemy(entity_position, completed_entity)

	# Reset processing flag after a small delay to ensure actions start
	#await get_tree().create_timer(0.1).timeout
	is_processing_completion = false
	# Clear any inputs that got buffered during completion
	input_buffer.clear()

func _on_enemy_reached(enemy):
	"""Called when player physically reaches an enemy - now just for slash animation"""
	print("Player reached enemy! Starting slash animation.")
	# Don't kill enemy here - let the player's slash animation handle it

func _on_player_slash_completed(enemy):
	"""Called when player finishes slash animation on an enemy"""
	print("Player slash completed! Now triggering enemy death.")

	if enemy != null and is_instance_valid(enemy):
		# If this is a boss, apply damage instead of killing outright
		var boss_max = enemy.get("max_boss_health") if enemy != null else null
		var is_boss = boss_max != null
		if is_boss and enemy.has_method("take_damage"):
			enemy.take_damage(player.global_position)
		elif enemy.has_method("play_death_animation"):
			enemy.play_death_animation()

	# Note: Room clearing is already handled in the room scripts via enemy death signals

func _process_single_character(key_typed: String):
	"""Process one character at a time to handle high WPM"""
	if is_processing_completion:
		return

	if active_enemy == null:
		find_new_active_enemy(key_typed)
		return

	# Validate current enemy - cached: avoid repeated property access
	if not is_instance_valid(active_enemy) or not active_enemy.has_method("get_prompt"):
		active_enemy = null
		current_letter_index = -1
		find_new_active_enemy(key_typed)
		return

	var prompt = active_enemy.get_prompt().to_lower()

	# Bounds check
	if current_letter_index < 0 or current_letter_index >= prompt.length():
		active_enemy = null
		current_letter_index = -1
		return

	var next_character = prompt.substr(current_letter_index, 1)
	if key_typed == next_character:
		# ADD SCORING LOGIC HERE
		update_score()
		Global.wpm_note_correct_characters(1)

		current_letter_index += 1

		# Update visual feedback - cached: minimize checks
		if is_instance_valid(active_enemy):
			active_enemy.set_next_character(current_letter_index)
			prompt_updated.emit(prompt, current_letter_index)  # After enemy.set_next_character()

		# Check completion
		if current_letter_index >= prompt.length():
			_complete_word()

func _unhandled_input(event: InputEvent) -> void:
	"""Handle keyboard input for typing"""
	if event is InputEventKey and event.pressed and not is_processing_completion:
		var typed_event := event as InputEventKey
		if typed_event.unicode != 0:
			var key_typed = PackedByteArray([typed_event.unicode]).get_string_from_utf8().to_lower()
			print("Key buffered:", key_typed)
			input_buffer.append(key_typed)

func setup_heart_container():
	"""Create and setup the heart container for the dungeon"""
	# Create canvas layer
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "CanvasLayer"
	add_child(canvas_layer)

	# Add heart container to the canvas layer
	var heart_container = load("res://Scenes/GUI/heart_container.tscn").instantiate()
	heart_container.name = "HeartContainer"
	canvas_layer.add_child(heart_container)

	# Initialize heart container with global health values - set health first
	heart_container.setMaxhearts(Global.player_max_health)
	heart_container.setHealth(Global.player_current_health)

	print("Heart container initialized for dungeon! Current health: ",
		Global.player_current_health, "/", Global.player_max_health)

func _on_health_changed(new_health: int, max_health: int):
	"""Update heart container when health changes"""
	var canvas_layer = get_node_or_null("CanvasLayer")
	if canvas_layer:
		var heart_container = canvas_layer.get_node_or_null("HeartContainer")
		if heart_container:
			# Update max hearts first, then health
			if heart_container.max_hearts != max_health:
				heart_container.setMaxhearts(max_health)
			heart_container.setHealth(new_health)
			print("Updated heart display! Current health: ", new_health, "/", max_health)

func setup_score_label():
	"""Create and setup the score label for the dungeon"""
	var canvas_layer = get_node_or_null("CanvasLayer")
	if not canvas_layer:
		# Create canvas layer if it doesn't exist
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		add_child(canvas_layer)

	# Add score label to the canvas layer
	var score_label = load("res://Scenes/current_score.tscn").instantiate()
	score_label.name = "CurrentScoreLabel"
	canvas_layer.add_child(score_label)

	print("Score label initialized for dungeon!")

func setup_active_buffs():
	"""Create and setup the active buffs display for the dungeon"""
	var canvas_layer = get_node_or_null("CanvasLayer")
	if not canvas_layer:
		# Create canvas layer if it doesn't exist
		canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		add_child(canvas_layer)

	# Add active buffs display to the canvas layer
	var active_buffs = load("res://Scenes/active_buffs.tscn").instantiate()
	active_buffs.name = "ActiveBuffs"
	canvas_layer.add_child(active_buffs)

	print("Active buffs display initialized for dungeon!")

func update_score():
	"""Update score tracking (called when correct characters are typed)"""
	Global.previous_score = Global.current_score
	if Global.current_score > Global.high_score:
		Global.high_score = Global.current_score
