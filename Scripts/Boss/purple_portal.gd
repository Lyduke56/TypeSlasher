extends Node2D

signal portal_selected(portal_index: int)
signal portal_activated

@onready var animated_sprite = $AnimatedSprite2D
@onready var area_2d = $AnimatedSprite2D/Area2D
@onready var label = $Location

var portal_index: int = 0

# Typing system variables (similar to enemies)
@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
var is_being_targeted: bool = false
var prompt_text: String = ""

# Enemy spawning variables
var NightBorneScene = preload("res://Scenes/Boss/NightBorne.tscn")
var spawn_timer: Timer
@export var spawn_interval: float = 3.0  # Spawn a NightBorne every 3 seconds
var target_position: Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	area_2d.body_entered.connect(_on_body_entered)

	# Set a random word for the portal
	var portal_word = _get_unique_word("medium")
	set_prompt(portal_word)

	# Setup enemy spawning timer
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.wait_time = spawn_interval
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_spawn_nightborne)
	spawn_timer.start()

	print("Purple portal activated - spawning NightBorne every ", spawn_interval, " seconds")

# --- Typing interface functions (similar to enemies) ---
func set_prompt(new_word: String) -> void:
	prompt_text = new_word
	label.parse_bbcode(new_word)  # start with plain text

func get_prompt() -> String:
	return prompt_text

func set_next_character(next_character_index: int):
	# Don't update visual feedback if portal is being targeted
	if is_being_targeted:
		return

	# Additional safety check
	if not is_instance_valid(self):
		return

	var full_text: String = get_prompt()

	# Bounds checking
	if next_character_index < -1 or next_character_index > full_text.length():
		print("Warning: Invalid character index: ", next_character_index)
		return

	var typed_part = ""
	var next_char_part = ""
	var remaining_part = ""

	# already typed → green
	if next_character_index > 0:
		typed_part = get_bbcode_color_tag(green) + full_text.substr(0, next_character_index) + get_bbcode_end_color_tag()

	# next character → blue
	if next_character_index >= 0 and next_character_index < full_text.length():
		next_char_part = get_bbcode_color_tag(blue) + full_text.substr(next_character_index, 1) + get_bbcode_end_color_tag()

	# remaining → normal
	if next_character_index + 1 < full_text.length():
		remaining_part = full_text.substr(next_character_index + 1)

	# apply to label
	label.parse_bbcode(typed_part + next_char_part + remaining_part)

func get_bbcode_color_tag(color: Color) -> String:
	return "[color=#" + color.to_html(false) + "]"

func get_bbcode_end_color_tag() -> String:
	return "[/color]"

func set_targeted_state(targeted: bool):
	"""Called when portal becomes targeted"""
	is_being_targeted = targeted
	if targeted:
		modulate = Color.GRAY  # Darken the portal
	else:
		modulate = Color.WHITE  # Reset color

func play_appear_animation():
	animated_sprite.play("appear")
	await animated_sprite.animation_finished
	animated_sprite.play("idle")

func play_disappear_animation():
	animated_sprite.play("disappear")
	await animated_sprite.animation_finished
	portal_selected.emit(portal_index)  # Portal selected for navigation
	portal_activated.emit()  # Emit activation signal before disappearing
	queue_free()

# Portal handled by typing completion now - kept for safety
func _on_body_entered(body: Node2D):
	pass  # Typing system handles portal activation now

func _spawn_nightborne():
	"""Spawn a NightBorne enemy at the portal's position"""
	# Get the parent container (EnemyContainer in the boss room)
	var parent_container = get_parent()

	if not parent_container:
		print("ERROR: Purple portal has no parent container!")
		return

	# Create NightBorne instance
	var nightborne = NightBorneScene.instantiate()
	nightborne.z_index = 3

	# Position at portal location
	nightborne.position = position

	# Make NightBorne faster than regular enemies
	nightborne.speed = 75.0  # Faster than orc's 50

	# Set target position (should be toward the center/target)
	if target_position != Vector2.ZERO:
		nightborne.set_target_position(target_position)
	else:
		# Fallback: try to find the Target node
		var target = get_tree().root.find_child("Target", true, false)
		if target:
			nightborne.set_target_position(target.global_position)

	# Add to enemy container first
	parent_container.add_child(nightborne)

	# Force the NightBorne to be ready and then set its word
	await get_tree().process_frame  # Wait one frame for nodes to be ready
	_setup_nightborne_prompt_immediately(nightborne)

	print("Purple portal spawned NightBorne at ", position)

func _setup_nightborne_prompt_immediately(nightborne: Node2D):
	"""Immediate setup of NightBorne prompt"""
	var enemy_word = _get_unique_word("medium")
	nightborne.set_prompt(enemy_word)
	print("NightBorne spawned with word: '", enemy_word, "'")

func _setup_nightborne_prompt(nightborne: Node2D):
	"""Deferred setup of NightBorne prompt"""
	var enemy_word = _get_unique_word("medium")
	nightborne.set_prompt(enemy_word)
	print("NightBorne spawned with word: '", enemy_word, "'")

func _get_unique_word(category: String = "medium") -> String:
	"""Get a unique word for the enemy"""
	if not WordDatabase:
		print("WordDatabase not loaded!")
		return "enemy"

	var available_words = WordDatabase.get_category_words(category)
	if available_words.is_empty():
		print("No words available in category: " + category)
		return "enemy"

	# Pick random word
	return available_words[randi() % available_words.size()]
