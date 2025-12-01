extends CanvasLayer

signal on_transition_finished

@onready var color_rect = $ColorRect
@onready var animation_player = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	color_rect.visible = false 
	animation_player.animation_finished.connect(_on_animation_finished)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_animation_finished(anim_name):
		if anim_name == "Fade_In":
			on_transition_finished.emit()
			animation_player.play("Fade_Out")
		elif anim_name == "Fade_Out":
			color_rect.visible = false

func transition():
	color_rect.visible = true 
	animation_player.play("Fade_In")
