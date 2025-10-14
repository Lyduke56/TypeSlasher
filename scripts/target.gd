extends Node2D

var health := 3
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	anim.play("Idle")

func take_damage() -> void:
	# Prevent overlapping hits while already playing the Hit animation
	if anim.is_playing() and anim.animation == "Hit":
		return
	
	health -= 1
	Global.take_damage(1)
	anim.play("Hit")
	
	# Return to Idle after the Hit animation finishes
	anim.connect("animation_finished", Callable(self, "_on_hit_finished"), CONNECT_ONE_SHOT)
	
	if health <= 0:
		anim.play("Death")
		get_tree().quit()

func _on_hit_finished(anim_name: String) -> void:
	if anim_name == "Hit" and health > 0:
		anim.play("Idle")
