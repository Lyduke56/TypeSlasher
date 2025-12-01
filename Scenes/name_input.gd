extends CanvasLayer

signal score_submitted
signal closed_without_submit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$LineEdit.add_theme_color_override("font_placeholder_color", Color.RED)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_close_pressed() -> void:
	closed_without_submit.emit()
	queue_free()


func _on_submit_pressed() -> void:
	var player_name = $LineEdit.text.strip_edges()
	if player_name == "":
		$LineEdit.placeholder_text = "PLEASE ENTER NAME"
		return

	# Format time from seconds to MM:SS
	var minutes = int(Global.game_total_time / 60)
	var seconds = int(Global.game_total_time) % 60
	var time_str = "%02d:%02d" % [minutes, seconds]

	# --- CRITICAL CONNECTION ---
	Global.add_score(player_name, time_str, Global.current_score)

	# Emit signal and exit scene
	score_submitted.emit()
	queue_free()
