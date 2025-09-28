extends Node2D
var health: int = 3
@onready var heart_container: HBoxContainer = get_node_or_null("/root/Game/CanvasLayer/HeartContainer")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func take_damage():
	health -= 1
	if heart_container:
		heart_container.setHealth(health)
	if health <= 0:
		get_tree().quit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
