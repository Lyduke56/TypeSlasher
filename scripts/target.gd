extends Node2D
@onready var animated_sprite = $AnimatedSprite2D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Health buffs are now applied in main_manager.gd
	animated_sprite.play("idle")
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
	animated_sprite.play("damaged")
	Global.take_damage(amount)
	if Global.player_current_health <= 0:
		animated_sprite.play("death")
		# Wait for death animation to finish
		await animated_sprite.animation_finished
		# Wait additional 2 seconds
		await get_tree().create_timer(2.0).timeout
		print("GAME OVER")
		get_tree().quit()
	else:
		# Wait for damaged animation to finish, then return to idle
		await animated_sprite.animation_finished
		animated_sprite.play("idle")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
