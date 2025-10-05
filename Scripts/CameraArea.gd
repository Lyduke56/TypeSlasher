extends Area2D

@onready var camera: Camera2D = $"../../Player/Camera2D"
@onready var player: Node = $"../../Player"
@onready var parent_room: Node2D = $".."

# Camera settings when anchored
@export var anchored_zoom: Vector2 = Vector2(0.5, 0.5)  # Adjust zoom level as needed
@export var normal_zoom: Vector2 = Vector2(1.0, 1.0)

var camera_original_parent: Node
var camera_original_position: Vector2
var camera_original_zoom: Vector2

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("CameraArea _ready, player ", player, " overlaps ", overlaps_body(player))
	# Check if player is already overlapping when area is ready (e.g., player starts in area)
	if player and overlaps_body(player):
		_on_body_entered(player)

func _on_body_entered(body: Node2D) -> void:
	if body == player:
		print("Player entered CameraArea of ", parent_room.name)
		# Set camera limits based on room bounds
		if parent_room.room_bounds != Rect2():
			var bounds = parent_room.room_bounds
			print("Setting camera limits: left ", bounds.position.x, " top ", bounds.position.y, " right ", bounds.end.x, " bottom ", bounds.end.y)
			camera.limit_left = bounds.position.x
			camera.limit_right = bounds.end.x
			camera.limit_top = bounds.position.y
			camera.limit_bottom = bounds.end.y
		# Set zoom based on room type
		var target_zoom = Vector2(1, 1)
		if parent_room.room_type == "Small":
			target_zoom = Vector2(0.67, 0.67)
		elif parent_room.room_type == "Medium":
			target_zoom = Vector2(0.5, 0.5)
		elif parent_room.room_type == "Boss":
			target_zoom = Vector2(0.4, 0.4)
		print("Current zoom ", camera.zoom, " target zoom ", target_zoom)
		if camera.zoom != target_zoom:
			print("Tweening zoom to ", target_zoom)
			var tween = get_tree().create_tween()
			tween.tween_property(camera, "zoom", target_zoom, 0.25)

func _on_body_exited(body: Node2D) -> void:
	# Optionally reset when exiting, but since all rooms have areas, not needed
	pass
