extends Node2D

@export var room_scene: PackedScene = preload("res://Scenes/Rooms/Dungeon-1.tscn")
@export var score_threshold: int = 100	# trigger score to show paths
@export var player_path: NodePath = NodePath("Main/Player")	# change to match your scene tree if needed

@export var up_offset: Vector2 = Vector2(0, -600)
@export var up_left_offset: Vector2 = Vector2(-400, -600)
@export var up_right_offset: Vector2 = Vector2(400, -600)

var current_room: Node = null
var rooms: Array = []
var path_options: Array = []	# stores Vector2 offsets for current choice set

var selection_layer: CanvasLayer
var selection_overlay: Control
var buttons_container: VBoxContainer
var info_label: Label

func _ready():
	randomize()
	spawn_room(Vector2.ZERO)	# initial starting room
	_build_selection_overlay()
	selection_overlay.visible = false

func spawn_room(position: Vector2) -> Node:
	var room = room_scene.instantiate()
	add_child(room)
	room.position = position
	rooms.append(room)
	current_room = room
	return room

func check_progress() -> void:
	# Call this from your game when score is updated.
	if Global.current_score >= score_threshold:
		_show_path_selection()
		return

# ---------- UI building ----------
func _build_selection_overlay() -> void:
	selection_layer = CanvasLayer.new()
	add_child(selection_layer)
	selection_layer.process_mode = Node.ProcessMode.PROCESS_MODE_WHEN_PAUSED

	selection_overlay = Control.new()
	selection_overlay.name = "PathSelectionOverlay"
	selection_overlay.process_mode = Node.ProcessMode.PROCESS_MODE_WHEN_PAUSED
	selection_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	selection_overlay.anchor_left = 0.0
	selection_overlay.anchor_top = 0.0
	selection_overlay.anchor_right = 1.0
	selection_overlay.anchor_bottom = 1.0
	selection_overlay.visible = false
	selection_layer.add_child(selection_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dim.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_overlay.add_child(dim)

	var panel := Panel.new()
	panel.anchor_left = 0.25
	panel.anchor_top = 0.25
	panel.anchor_right = 0.75
	panel.anchor_bottom = 0.75
	selection_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.margin_left = 12
	vbox.margin_top = 12
	vbox.margin_right = -12
	vbox.margin_bottom = -12
	panel.add_child(vbox)

	info_label = Label.new()
	info_label.text = "Choose a path"
	info_label.horizontal_alignment = Label.ALIGN_CNTER
	vbox.add_child(info_label)

	buttons_container = VBoxContainer.new()
	buttons_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(buttons_container)

# ---------- path selection logic ----------
func _show_path_selection() -> void:
	# Decide 1..3 random paths (always at least 1)
	var path_count = int(randi() % 3) + 1
	var dirs = [up_offset, up_left_offset, up_right_offset]
	dirs.shuffle()

	path_options.clear()
	for i in range(path_count):
		path_options.append(dirs[i])

	# Clear existing buttons
	for child in buttons_container.get_children():
		child.queue_free()

	# Build buttons for each option
	for i in range(path_options.size()):
		var dir = path_options[i]
		var label = _dir_to_label(dir)
		var b = Button.new()
		b.text = "%s" % label
		b.expand = true
		buttons_container.add_child(b)
		# bind index so _on_path_selected receives which option was chosen
		b.connect("pressed", Callable(self, "_on_path_selected"), [i])

	# Show overlay and pause the game
	selection_overlay.visible = true
	get_tree().paused = true

func _dir_to_label(dir: Vector2) -> String:
	if dir == up_offset:
		return "Up"
	elif dir == up_left_offset:
		return "Up-Left"
	elif dir == up_right_offset:
		return "Up-Right"
	return "Path"

func _on_path_selected(index: int) -> void:
	# Hide UI and unpause
	selection_overlay.visible = false
	get_tree().paused = false

	# Spawn the selected room and move the player
	if index >= 0 and index < path_options.size():
		var dir = path_options[index]
		var new_room = spawn_room(current_room.position + dir)

		# Find player node (tries relative first, then root lookup)
		var player_node = null
		if has_node(player_path):
			player_node = get_node(player_path)
		else:
			player_node = get_tree().get_root().get_node_or_null(player_path)

		if player_node:
			# use global_position so teleportation is robust
			player_node.global_position = new_room.global_position + Vector2(0, 100)

	# Reset score to avoid immediate re-trigger (you can change to carry-over if you want)
	Global.current_score = 0
