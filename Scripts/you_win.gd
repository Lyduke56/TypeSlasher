extends CanvasLayer
@onready var animation_player = $AnimationPlayer
@onready var color_rect = $AnimationPlayer/ColorRect
@onready var score_label = $Score
@onready var time_label = $Time

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	score_label.text = "Score: " + str(Global.current_score)
	time_label.text = "Play Time: " + Global.get_formatted_time()
	animation_player.play("Fade_in")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
