extends Node2D

enum RoomType { SMALL, MEDIUM, BOSS, HEALING }

@export var room_type: RoomType = RoomType.HEALING
var is_cleared: bool = false
var is_ready_to_clear: bool = false

# === Room connectivity ===
var connected_rooms: Dictionary = {} # "direction": room_node
var enter_marker: Marker2D
var exit_markers: Dictionary = {} # "direction": marker_node

signal room_started
signal room_cleared

# === Nodes ===
@onready var camera_area: Area2D = $Camera2D
@onready var goddess_container: Node2D = $GoddessContainer
@onready var target_container: Node2D = $TargetContainer
@onready var top_marker: Marker2D = $Top

# === Goddess statue setup ===
var goddess_scene: PackedScene = preload("res://Scenes/goddess_statue.tscn")
var goddess_instance: Node2D
var statue_word: String = ""
@export var words_file_path: String = "res://data/words.json"

func _ready() -> void:
	print("🌿 Healing room ready: " + name)

	# Register top exit marker for dungeon linking
	for child in get_children():
		if child is Marker2D:
			exit_markers[child.name.to_lower()] = child
	enter_marker = get_node_or_null("Enter")

	# Connect camera signals (if used for transitions)
	if not camera_area.body_entered.is_connected(_on_camera_area_body_entered):
		camera_area.body_entered.connect(_on_camera_area_body_entered)
	if not camera_area.body_exited.is_connected(_on_camera_area_body_exited):
		camera_area.body_exited.connect(_on_camera_area_body_exited)

	_spawn_goddess_statue()

func _spawn_goddess_statue():
	goddess_instance = goddess_scene.instantiate()
	goddess_container.add_child(goddess_instance)
	goddess_instance.position = Vector2.ZERO

	var anim: AnimatedSprite2D = goddess_instance.get_node("AnimatedSprite2D")
	var word_label: RichTextLabel = goddess_instance.get_node("Word")
	var area: Area2D = goddess_instance.get_node("Area2D")

	# Assign random word from words.json (goddess category)
	statue_word = _get_random_word_from_json()
	if statue_word == "":
		statue_word = "blessing"
	word_label.text = statue_word
	word_label.parse_bbcode(statue_word)

	anim.play("goddess_idle")

	# Connect interaction
	if not area.is_connected("body_entered", _on_goddess_area_entered):
		area.connect("body_entered", _on_goddess_area_entered)

	print("🕊️ Goddess statue ready with word:", statue_word)

# === Connectivity ===
func set_connected_room(direction: String, room_node: Node2D):
	connected_rooms[direction] = room_node

func get_connected_room(direction: String) -> Node2D:
	return connected_rooms.get(direction, null)

# === Player interactions ===
func _on_goddess_area_entered(body: Node2D) -> void:
	if body.name == "Player":
		print("🙏 Player approached the goddess statue.")
		_show_goddess_prompt()

func _show_goddess_prompt():
	print("💬 Type word to receive blessing:", statue_word)

# === JSON word loading ===
func _get_random_word_from_json() -> String:
	var file = FileAccess.open(words_file_path, FileAccess.READ)
	if file == null:
		push_warning("⚠️ Failed to open words.json at: " + words_file_path)
		return ""

	var data = file.get_as_text()
	var json = JSON.new()
	var result = json.parse(data)
	if result != OK:
		push_warning("⚠️ Failed to parse words.json: " + json.get_error_message())
		return ""

	var words = json.get_data()
	if not words.has("goddess"):
		push_warning("⚠️ Missing 'goddess' category in words.json")
		return ""

	var arr = words["goddess"]
	if arr.is_empty():
		push_warning("⚠️ Goddess category is empty in words.json")
		return ""

	return arr[randi() % arr.size()]

# === Camera handling ===
func _on_camera_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		update_camera()
		print("Player entered healing room:", name)

func _on_camera_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		print("Player exited healing room:", name)

func update_camera():
	var player = get_node("/root/Main/Player")
	if player and player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		var shape = camera_area.get_node("CollisionShape2D")
		if shape and shape.shape is RectangleShape2D:
			var rect = shape.shape.get_rect()
			var center = camera_area.global_position - rect.get_center()
			camera.limit_left = center.x - rect.size.x / 2
			camera.limit_right = center.x + rect.size.x / 2
			camera.limit_top = center.y - rect.size.y / 2
			camera.limit_bottom = center.y + rect.size.y / 2
