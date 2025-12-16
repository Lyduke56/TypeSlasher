extends PanelContainer

@onready var icon = $ICON

# preload your buff icons
var buff_icons = [
	preload("res://Assets/Sprites/GUI/Buff_HealthPotion.png"),
	preload("res://Assets/Sprites/GUI/Buff_Shield.png"),
	preload("res://Assets/Sprites/GUI/Buff_sword.png")
]

var chosen_index = 0
var spin_timer: Timer
var auto_timer: Timer
var is_auto_spinning = false

func set_icon(index: int):
	chosen_index = index
	if buff_icons[index]:
		icon.texture = buff_icons[index]

func _ready() -> void:
	# Create spin timer for rapid cycling
	spin_timer = Timer.new()
	spin_timer.wait_time = 0.1  # Fast spin
	add_child(spin_timer)
	spin_timer.timeout.connect(_on_spin_timeout)

	# Create auto-stop timer
	auto_timer = Timer.new()
	auto_timer.wait_time = 3.0
	auto_timer.one_shot = true
	auto_timer.timeout.connect(_on_auto_timeout)
	add_child(auto_timer)

	# Start auto-spinning immediately
	start_auto_spin()

func _on_spin_timeout():
	chosen_index = (chosen_index + 1) % buff_icons.size()
	if buff_icons[chosen_index]:
		icon.texture = buff_icons[chosen_index]

func _on_auto_timeout():
	if is_auto_spinning:
		if spin_timer:
			spin_timer.stop()
		is_auto_spinning = false
		# Random at stop
		var random_index = randi() % buff_icons.size()
		chosen_index = random_index
		if buff_icons[random_index]:
			icon.texture = buff_icons[random_index]

func start_auto_spin():
	is_auto_spinning = true
	if spin_timer:
		chosen_index = 0  # Start from first
		if buff_icons[0]:
			icon.texture = buff_icons[0]
		spin_timer.start()
	# Start 3-second timer to stop
	auto_timer.start()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if auto_timer:
			auto_timer.stop()
		if spin_timer:
			spin_timer.stop()
		is_auto_spinning = false
		# Determine which icon was shown at click time
		for i in range(buff_icons.size()):
			if icon.texture == buff_icons[i]:
				chosen_index = i
				break
