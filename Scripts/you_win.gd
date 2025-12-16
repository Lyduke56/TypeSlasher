extends CanvasLayer
@onready var animation_player = $AnimationPlayer
@onready var color_rect = $AnimationPlayer/ColorRect
@onready var score_label = $Score
@onready var time_label = $Time
@onready var save_score_button = $VBoxContainer/Save_Score
@onready var menu_button = $VBoxContainer/Menu
@onready var ng_button = $VBoxContainer/NG

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	score_label.text = "Score: " + str(Global.current_score)
	time_label.text = "Play Time: " + Global.get_formatted_time()
	animation_player.play("Fade_in")

	if ng_button:
		ng_button.pressed.connect(_on_ng_pressed)

		var next_cycle = DungeonProgress.ng_plus_cycle + 1
		ng_button.text = "Begin Journey " + str(next_cycle)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_menu_pressed() -> void:
	# Go back to Main Menu (or directly to the game if you prefer)
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")


func _on_save_score_pressed() -> void:
	var name_input_scene = load("res://Scenes/Name_Input.tscn").instantiate()
	add_child(name_input_scene)
	name_input_scene.score_submitted.connect(_on_score_submitted)
	name_input_scene.closed_without_submit.connect(_on_name_input_closed)
	menu_button.disabled = true
	save_score_button.disabled = true


func _on_score_submitted() -> void:
	menu_button.disabled = false


func _on_name_input_closed() -> void:
	menu_button.disabled = false
	save_score_button.disabled = false


func _on_ng_pressed() -> void:
	DungeonProgress.start_ng_plus()
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
