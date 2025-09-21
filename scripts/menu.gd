extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$VBoxContainer/Start_button.grab_focus()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	$AnimationPlayer.play("Fade_out_to_game")


func _on_option_button_pressed() -> void:
	pass # Replace with function body.


func _on_close_button_pressed() -> void:
	get_tree().quit()


func _on_score_button_pressed() -> void:
	pass # Replace with function body.

func start_game():
	get_tree().change_scene_to_file("res://scenes/game.tscn")
