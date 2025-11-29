extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_close_pressed() -> void:
	queue_free()


func _on_submit_pressed() -> void:
	var player_name = $LineEdit.text
	if player_name == "":
		player_name = "Unknown"

	# Format time from seconds to MM:SS
	var minutes = int(Global.game_total_time / 60)
	var seconds = int(Global.game_total_time) % 60
	var time_str = "%02d:%02d" % [minutes, seconds]

	# --- CRITICAL CONNECTION ---
	Global.add_score(player_name, time_str, Global.current_score)

	# Move to Leaderboard
	get_tree().change_scene_to_file("res://Scenes/Leaderboard.tscn")
