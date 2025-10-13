extends HBoxContainer
@onready var HeartGuiClass = preload("res://scenes/GUI/HeartGUI.tscn")

var max_hearts: int = 0

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

func increaseMaxHealth(amount: int = 1):
	"""Increase the maximum health by the specified amount"""
	Global.player_max_health += amount
	setMaxhearts(Global.player_max_health)
	setHealth(Global.player_current_health)  # Refresh current health display
	print("Player max health increased to: ", Global.player_max_health)
