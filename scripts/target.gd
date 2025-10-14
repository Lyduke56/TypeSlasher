extends Node2D
var health: int = 1
@onready var heart_container: HBoxContainer = get_node_or_null("/root/Game/CanvasLayer/HeartContainer")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Check if there's a health buff applied from previous buff selection
	if Global.get("health_buff_applied") == true:
		Global.health_buff_applied = false
		apply_health_buff()

# Add extra health for Health Potion buff (index 0)
func apply_health_buff():
	"""Apply health potion buff - add +1 max health"""
	var old_health = health
	health += 1
	print("Health Potion buff applied! Health increased from", old_health, "to", health)

	# Update the heart container to show the new max health
	if heart_container:
		heart_container.setMaxhearts(health)

func take_damage():
	health -= 1
	if heart_container:
		heart_container.setHealth(health)
	if health <= 0:
		get_tree().quit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
