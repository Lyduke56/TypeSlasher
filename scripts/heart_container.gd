extends HBoxContainer
@onready var HeartGuiClass = preload("res://scenes/GUI/HeartGUI.tscn")

var max_hearts: int = 1000

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setMaxhearts(max: int):
	max_hearts = max
	for i in range(max):
		var heart = HeartGuiClass.instantiate()
		add_child(heart)

func setHealth(hp: int):
	for i in range(max_hearts):
		if i < hp:
			get_child(i).visible = true
		else:
			get_child(i).visible = false
