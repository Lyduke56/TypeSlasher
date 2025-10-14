extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Check if there's a health buff applied from previous buff selection
	if Global.health_buff_applied:
		Global.health_buff_applied = false
		apply_health_buff()

# Add extra health for Health Potion buff (index 0)
func apply_health_buff():
	"""Apply health potion buff - add +1 to max health (current health stays the same)"""
	Global.player_max_health += 1
	Global.player_health_changed.emit(Global.player_current_health, Global.player_max_health)
	print("Health Potion buff applied! Max health increased to: ", Global.player_max_health, " (current health remains ", Global.player_current_health, ")")

func take_damage(amount: int = 1):
	"""Take damage through global health system"""
	Global.take_damage(amount)
	if Global.player_current_health <= 0:
		get_tree().quit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
