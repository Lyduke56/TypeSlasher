extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Health buffs are now applied in main_manager.gd
	pass

# Add extra health for Health Potion buff (index 0)
func apply_health_buff():
	"""Apply health potion buff - add +1 to both max health and current health"""
	Global.player_max_health += 1
	Global.player_current_health += 1
	Global.player_health_changed.emit(Global.player_current_health, Global.player_max_health)
	print("Health Potion buff applied! Max health increased to: ", Global.player_max_health, " and current health increased to: ", Global.player_current_health)

func take_damage(amount: int = 1):
	"""Take damage through global health system"""
	Global.take_damage(amount)
	if Global.player_current_health <= 0:
		get_tree().quit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
