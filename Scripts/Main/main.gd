extends Node2D
@onready var heart_container: HBoxContainer = $HUD/HeartContainer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize heart container with current global health values
	if heart_container:
		heart_container.initialize_hearts()
		print("Main scene heart container initialized with health: ", Global.player_current_health, "/", Global.player_max_health)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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

	# Initialize heart container with global health values
	heart_container.setMaxhearts(Global.player_max_health)
	heart_container.setHealth(Global.player_current_health)

	print("Heart container initialized for dungeon!")
