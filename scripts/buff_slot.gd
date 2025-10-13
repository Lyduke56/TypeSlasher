extends PanelContainer

@onready var icon = $ICON
@onready var anim: AnimationPlayer = $Spin

# preload your buff icons
var buff_icons = [
	preload("res://Assets/Sprites/GUI/Buff_HealthPotion.png"),
	preload("res://Assets/Sprites/GUI/Buff_Shield.png"),
	preload("res://Assets/Sprites/GUI/Buff_sword.png")
]

var chosen_index = 0
var auto_timer: Timer
var is_auto_spinning = false

func set_icon(index: int):
	chosen_index = index
	icon.texture = buff_icons[index]

func _ready() -> void:
	# Create auto-spin timer
	auto_timer = Timer.new()
	auto_timer.wait_time = 3.0
	auto_timer.one_shot = true
	auto_timer.timeout.connect(_on_auto_timeout)
	add_child(auto_timer)

	# Ensure randomization is seeded - call randomize once per session if not done
	if not get_node_or_null("/root/Global") or (get_node_or_null("/root/Global") and not get_node("/root/Global").random_seed_set):
		randomize()
		var global_node = get_node_or_null("/root/Global")
		if global_node == null:
			global_node = load("res://Scripts/global.gd").new()
			get_tree().root.add_child(global_node)
		global_node.random_seed_set = true

	# Start with a random initial icon to ensure fairness
	set_icon(randi() % buff_icons.size())

	# Start auto-spinning immediately when the slot is created
	start_auto_spin()

func start_auto_spin():
	"""Start the automatic spinning animation"""
	is_auto_spinning = true
	if anim and anim.has_animation("Spin"):
		anim.play("Spin")
		anim.seek(0.0)
	# Start the 3-second timer
	auto_timer.start()

func _on_auto_timeout() -> void:
	if is_auto_spinning and anim:
		anim.stop()
		# Pick a random icon to stop on
		var random_index = randi() % buff_icons.size()
		icon.texture = buff_icons[random_index]
		chosen_index = random_index
		is_auto_spinning = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Stop any ongoing auto animation and use current selection
		auto_timer.stop()
		if anim:
			anim.stop()
		is_auto_spinning = false
		# Keep the current chosen icon
		if chosen_index >= 0 and chosen_index < buff_icons.size():
			icon.texture = buff_icons[chosen_index]
