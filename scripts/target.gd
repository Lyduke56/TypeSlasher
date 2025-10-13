extends Node2D
var health: int = 3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func take_damage():
	health -= 1
	# Use global damage system for visual updates
	Global.take_damage(1)
	if health <= 0:
		get_tree().quit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
