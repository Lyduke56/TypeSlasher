extends CanvasLayer
@onready var animation_player = $AnimationPlayer
@onready var color_rect = $AnimationPlayer/ColorRect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animation_player.play("Fade_in")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")


func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")
