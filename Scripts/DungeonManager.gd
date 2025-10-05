extends Node

@export var player: NodePath
@export var starting_room: NodePath

var current_room: Node

# Typing mechanic
var active_entity = null
var current_letter_index: int = -1
var input_buffer: Array[String] = []
var is_processing_completion: bool = false

func _ready():
	current_room = get_node_or_null(starting_room)
	if is_instance_valid(current_room):
		current_room.room_cleared.connect(_on_room_cleared)
		enter_room(current_room)
	else:
		push_error("Starting room not found: " + str(starting_room))

func _process(_delta):
	# Process input buffer
	if not input_buffer.is_empty() and not is_processing_completion:
		var key_typed = input_buffer.pop_front()
		_process_single_character(key_typed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var typed_event := event as InputEventKey
		if typed_event.unicode != 0:
			var key_typed = PackedByteArray([typed_event.unicode]).get_string_from_utf8().to_lower()
			print("Key buffered:", key_typed)
			input_buffer.append(key_typed)

func _on_room_cleared():
	pass  # Hallway prompts are set in Room.gd set_cleared

func get_available_directions() -> Array:
	var dirs = ["Top", "Right", "Bottom", "Left"]
	var available = []
	for dir in dirs:
		if current_room.get_exit_marker(dir):
			available.append(dir)
	return available

func on_player_typed_direction(direction: String):
	if not (direction in get_available_directions()):
		return
	var target_room_path = current_room.adjacent_rooms.get(direction)
	if target_room_path:
		var target_room = get_node(target_room_path)
		await walk_hallway_and_enter(current_room, target_room, direction)
		enter_room(target_room)

func walk_hallway_and_enter(current_room: Node, target_room: Node, direction: String):
	var exit_marker = current_room.get_exit_marker(direction)
	await tween_player_to(exit_marker.global_position)
	var opposite = get_opposite_direction(direction)
	var entrance_marker = target_room.get_exit_marker(opposite)
	await tween_player_to(entrance_marker.global_position)

func enter_room(room: Node):
	var previous_room = current_room
	current_room.room_cleared.disconnect(_on_room_cleared)
	current_room = room
	current_room.room_cleared.connect(_on_room_cleared)
	current_room.set_cleared()  # Enable hallway directions for room transition

	# Hide hallways in previous room
	if previous_room and is_instance_valid(previous_room):
		for child in previous_room.get_children():
			if child.name.begins_with("Hallway") and child.has_node("RichTextLabel"):
				child.get_node("RichTextLabel").visible = false

	# Camera adjustments now handled by CameraArea collisions
	# Disabled spawning for now, focus on room transition
	# room.start_room()

func room_type_to_zoom(type: String) -> Vector2:
	if type == "Small":
		return Vector2(0.67, 0.67)
	elif type == "Medium":
		return Vector2(0.5, 0.5)
	elif type == "Boss":
		return Vector2(0.4, 0.4)
	else:
		return Vector2(1, 1)

func tween_player_to(target_pos: Vector2):
	var tween = get_tree().create_tween()
	tween.tween_property(get_node(player), "position", target_pos, 1.0)
	await tween.finished

func get_opposite_direction(dir: String) -> String:
	if dir == "Top":
		return "Bottom"
	elif dir == "Bottom":
		return "Top"
	elif dir == "Left":
		return "Right"
	elif dir == "Right":
		return "Left"
	else:
		return ""

func find_new_active_entity(typed_character: String):
	if is_processing_completion:
		return

	if active_entity == null:
		# Check hallway entrances in current room
		for child in current_room.get_children():
			if child.name.begins_with("Hallway") and child.has_method("get_prompt"):
				var prompt = child.get_prompt().to_lower()
				if prompt.length() > 0 and prompt.substr(0, 1).to_lower() == typed_character:
					print("Found hallway that starts with ", typed_character, ": ", prompt)
					active_entity = child
					child.set_targeted_state(true)
					current_letter_index = 1
					child.set_next_character(current_letter_index)
					break

func _process_single_character(key_typed: String):
	"""Process one character for entity typing"""
	if is_processing_completion:
		return

	if active_entity == null:
		find_new_active_entity(key_typed)
		return

	if not is_instance_valid(active_entity) or active_entity.is_being_targeted:
		active_entity = null
		current_letter_index = -1
		find_new_active_entity(key_typed)
		return

	var prompt = active_entity.get_prompt().to_lower()

	if current_letter_index < 0 or current_letter_index >= prompt.length():
		print("Index out of bounds, resetting")
		active_entity = null
		current_letter_index = -1
		return

	var next_character = prompt.substr(current_letter_index, 1)
	if key_typed == next_character:
		print("Success! Typed:", key_typed, " Expected:", next_character)
		Global.wpm_note_correct_characters(1)
		current_letter_index += 1

		if is_instance_valid(active_entity):
			active_entity.set_next_character(current_letter_index)

		if current_letter_index >= prompt.length():
			_complete_entity()
	else:
		print("Wrong character! Typed:", key_typed, " Expected:", next_character)

func _complete_entity():
	"""Handle entity completion"""
	if is_processing_completion:
		return

	is_processing_completion = true

	print("Entity completed!")

	if active_entity != null:
		active_entity.set_targeted_state(false)
		# Hide text
		if active_entity.has_method("set_prompt"):
			active_entity.text_label.visible = false  # or however

		# Get direction from prompt
		var dir = active_entity.get_prompt().capitalize()  # right -> Right
		print("Moving in direction: ", dir)
		on_player_typed_direction(dir)

	active_entity = null
	current_letter_index = -1
	input_buffer.clear()

	is_processing_completion = false
