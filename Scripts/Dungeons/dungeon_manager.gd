extends Node2D

var current_room: Node2D
var rooms: Array[Node2D] = []
var player: CharacterBody2D
var is_transitioning: bool = false

@onready var direction_prompt: CanvasLayer = $DirectionPrompt
@onready var direction_label: RichTextLabel = $"../DirectionPrompt/Word"

var tween: Tween

func _ready() -> void:
	set_process_input(true)

	# Find all rooms in the scene
	for child in get_parent().get_children():
		if child.has_method("start_room"): # safer room detection
			rooms.append(child)

	# Set connections manually for now (can be exported later)
	setup_room_connections()

	# Find player
	player = get_node("../Player")

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


# ------------------------------------------------------------
# ROOM CONNECTION SETUP
# ------------------------------------------------------------
func setup_room_connections():
	var starting = get_node("../StartingRoom")
	var room_a = get_node("../RoomA - Medium")
	var room_b = get_node("../RoomB - Small")
	var room_c = get_node("../RoomC - Medium")
	var portal = get_node("../PortalRoom")

	starting.set_connected_room("right", room_a)
	starting.set_connected_room("bottom", room_b)

	room_a.set_connected_room("bottom", portal)
	room_a.set_connected_room("left", starting)

	room_b.set_connected_room("top", starting)
	room_b.set_connected_room("left", room_c)

	room_c.set_connected_room("right", room_b)

	portal.set_connected_room("top", room_a)


# ------------------------------------------------------------
# DIRECTION PROMPT
# ------------------------------------------------------------
func show_directions():
	if current_room.is_cleared:
		var directions = current_room.exit_markers.keys()
		direction_label.text = "Type direction: " + ", ".join(directions)
		direction_label.visible = true
	else:
		direction_label.visible = false


# ------------------------------------------------------------
# INPUT HANDLING (WASD for now)
# ------------------------------------------------------------
func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		var direction = ""
		match event.keycode:
			KEY_W:
				direction = "top"
			KEY_S:
				direction = "bottom"
			KEY_A:
				direction = "left"
			KEY_D:
				direction = "right"

		if direction != "" and current_room.exit_markers.has(direction) and not self.is_transitioning:
			transition_to_room(direction)


# ------------------------------------------------------------
# ROOM TRANSITIONS
# ------------------------------------------------------------
func transition_to_room(direction: String):
	var next_room = current_room.get_connected_room(direction)
	if not next_room:
		return

	print("Transitioning from %s to %s via %s" %
		[current_room.name, next_room.name, direction])

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

	# Check for TargetContainer in the new room
	var center_marker = next_room.get_node_or_null("TargetContainer")
	var final_position = center_marker.global_position if center_marker else (enter_marker.global_position if enter_marker is Marker2D else enter_marker)

	self.is_transitioning = true

	# Disable player input during tween
	player.set_process_input(false)

	tween = create_tween()
	player.reset_combo()

	tween.tween_property(player, "global_position", exit_marker.global_position, 0.8).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(player, "global_position", final_position, 0.8).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		# Disable previous room's camera
		if current_room.has_node("Camera2D"):
			current_room.get_node("Camera2D").current = false

		# Switch to new room
		current_room = next_room
		next_room.start_room()  # This should enable the new room's camera
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
					var target_pos = camera_area.global_position

					# Animate camera zoom and position
					if tween:
						tween.kill()
					tween = create_tween()
					tween.set_trans(Tween.TRANS_SINE)
					tween.set_ease(Tween.EASE_IN_OUT)
					tween.tween_property(camera, "zoom", target_zoom, 0.5)
					tween.tween_property(camera, "global_position", target_pos, 0.5)
					await tween.finished  # Wait for camera animation

					# Reset limits to allow zooming
					camera.limit_left = -1000000
					camera.limit_right = 1000000
					camera.limit_top = -1000000
					camera.limit_bottom = 1000000

		player.set_process_input(true)
		self.is_transitioning = false
		player.center_position = final_position
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
