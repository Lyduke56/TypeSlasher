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
	var ui_scene = preload("res://Scenes/GUI/UI.tscn")
	var ui_instance = ui_scene.instantiate()
	# Add to a CanvasLayer to overlay on the whole screen
	var canvas = CanvasLayer.new()
	canvas.name = "SettingsCanvas"
	get_tree().root.add_child(canvas)
	canvas.add_child(ui_instance)
	ui_instance.menu.visible = false
	ui_instance.information.visible = false
	ui_instance.settings.visible = true
	ui_instance.buff.visible = false
	# Disconnect existing close handler and connect to remove the canvas
	var close_button = ui_instance.get_node("Settings/Close")
	if close_button.pressed.is_connected(ui_instance._on_settings_close_pressed):
		close_button.pressed.disconnect(ui_instance._on_settings_close_pressed)
	close_button.pressed.connect(func(): canvas.queue_free())


func _on_close_button_pressed() -> void:
	get_tree().quit()


func _on_score_button_pressed() -> void:
	var leaderboard_scene = preload("res://Scenes/Leaderboard.tscn")
	var leaderboard_instance = leaderboard_scene.instantiate()
	get_tree().root.add_child(leaderboard_instance)

func start_game():
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _input(event):
	# Press F1 to generate scores
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		print("DEBUG: Generating fake scores...")
		var names = ["Player", "SpeedRunner", "Dev", "Tester", "Pro"]

		for i in range(10):
			var random_name = names.pick_random() + str(randi() % 99)
			var random_score = randi_range(500, 50000)
			var mm = randi_range(1, 15)
			var ss = randi_range(0, 59)
			var time_str = "%02d:%02d" % [mm, ss]

			Global.add_score(random_name, time_str, random_score)

		print("DEBUG: Added 10 scores!")
