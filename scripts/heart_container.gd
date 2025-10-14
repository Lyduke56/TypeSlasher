extends HBoxContainer
@onready var HeartGuiClass = preload("res://scenes/GUI/HeartGUI.tscn")

var max_hearts: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Heart container _ready called with global values: max_health=", Global.player_max_health, ", current_health=", Global.player_current_health)
	# Connect to global health signal for real-time updates
	Global.player_health_changed.connect(_on_player_health_changed)
	initialize_hearts()

func initialize_hearts():
	"""Initialize hearts based on current global values"""
	setMaxhearts(Global.player_max_health)
	setHealth(Global.player_current_health)

func _on_player_health_changed(new_health: int, max_health: int):
	"""Update heart display when health changes"""
	setHealth(new_health)
	if max_health != max_hearts:
		setMaxhearts(max_health)

func take_damage(amount: int = 1):
	"""Convenience function to take damage"""
	Global.take_damage(amount)

func heal_damage(amount: int = 1):
	"""Convenience function to heal damage"""
	Global.heal_damage(amount)

func setMaxhearts(max: int):
	max_hearts = max
	# Clear existing hearts
	for child in get_children():
		child.queue_free()
	# Create new hearts
	for i in range(max):
		var heart = HeartGuiClass.instantiate()
		add_child(heart)

func setHealth(hp: int):
	print("Setting heart container health to: ", hp, "(current max_hearts:", max_hearts, ")")
	for i in range(max_hearts):
		if i < hp:
			get_child(i).visible = true
			print("Heart ", i, " visible: true")
		else:
			get_child(i).visible = false
			print("Heart ", i, " visible: false")

func increaseMaxHealth(amount: int = 1):
	"""Increase the maximum health by the specified amount"""
	Global.player_max_health += amount
	setMaxhearts(Global.player_max_health)
	setHealth(Global.player_current_health)  # Refresh current health display
	print("Player max health increased to: ", Global.player_max_health)
