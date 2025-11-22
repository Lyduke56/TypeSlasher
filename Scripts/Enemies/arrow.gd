extends Node2D

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")

@export var speed: float = 150.0  # Projectile speed
@export var lifetime: float = 10.0  # How long arrow lives before disappearing
@onready var anim = $AnimatedSprite2D

# Room reference for word coordination
var associated_room: Node2D = null
@onready var word: RichTextLabel = $Word
@onready var prompt = $Word
@onready var prompt_text = prompt.text
@onready var area: Area2D = $Area2D

# Target tracking
var target_position: Vector2
var has_target: bool = false

# Targeting state - prevents retyping once word is completed
var is_being_targeted: bool = false

# Projectile state
var direction: Vector2
var lifetime_timer: Timer

@export var points_for_kill = 50

func _ready() -> void:
	# Setup lifetime timer
	lifetime_timer = Timer.new()
	add_child(lifetime_timer)
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_expired)
	lifetime_timer.start()

	# Connect collision signal
	area.body_entered.connect(_on_body_entered)
	# Connect animation finished signal
	if anim:
		anim.animation_finished.connect(_on_animation_finished)

	# Calculate direction to target
	if has_target:
		direction = (target_position - global_position).normalized()
		# Rotate only the arrow sprite to face the target, leave text upright
		var arrow_rotation = direction.angle()
		if anim:
			anim.rotation = arrow_rotation

	pass  # Word will be set by the game manager via set_prompt()

func _process(delta: float) -> void:
	pass

# --- Set word from spawner ---
func set_prompt(new_word: String) -> void:
	word.text = new_word  # keep a clean text for reference
	word.parse_bbcode(new_word)  # start with plain text

func get_prompt() -> String:
	return word.text

# --- Set target position (where to move towards) ---
func set_target_position(target: Vector2) -> void:
	target_position = target
	has_target = true
	print("Enemy target set to: ", target)

func set_next_character(next_character_index: int):
	# Don't update visual feedback if enemy is being targeted
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
	word.parse_bbcode(typed_part + next_char_part + remaining_part)

func get_bbcode_color_tag(color: Color) -> String:
	return "[color=#" + color.to_html(false) + "]"

func get_bbcode_end_color_tag() -> String:
	return "[/color]"

func set_targeted_state(targeted: bool):
	"""Called when enemy becomes targeted - stops movement and plays idle"""
	is_being_targeted = targeted
	if targeted:
		# Stop moving and play idle animation when targeted
		if anim:
			anim.play("arrow_idle")
		modulate = Color.GRAY  # Darken the enemy
	else:
		modulate = Color.WHITE  # Reset color

func play_death_animation():
	"""Arrow only has idle animation - just award points and remove"""
	Global.current_score += points_for_kill
	# Check for Sword buff health restoration
	Global.on_enemy_killed()
	queue_free()  # Remove enemy from scene

	print("Arrow killed - awarded points and removed")

func _on_lifetime_expired():
	"""Called when arrow lifetime expires"""
	if not is_being_targeted:
		queue_free()
		print("Arrow expired and was removed")

func _on_body_entered(body: Node2D):
	"""Called when arrow collides with target"""
	# Check if collided with target (target has StaticBody2D)
	$sfx_hit.play()
	if body is StaticBody2D and body.get_parent().name == "Target":
		# Arrow hit the target - deal damage and destroy arrow
		var target_node = body.get_parent()
		if target_node and target_node.has_method("take_damage"):
			target_node.take_damage()
			print("Arrow hit target and dealt damage!")

		# Destroy arrow immediately
		queue_free()

func _on_animation_finished():
	"""Called when any animation finishes"""
	# Arrow only has idle animation, so just ensure it stays idle when not targeted
	if anim and not is_being_targeted:
		anim.play("arrow_idle")
		
func _physics_process(delta: float) -> void:
	# Stop movement if being targeted (being typed)
	if is_being_targeted:
		return

	# Move toward target if we have one
	if has_target and direction != Vector2.ZERO:
		global_position += direction * speed * delta

		# Check if we've reached close to target position
		if global_position.distance_to(target_position) < 10.0:
			# Hit the target
			var target_node = get_node("/root/Main/Target")
			if target_node and target_node.has_method("take_damage"):
				target_node.take_damage()
				print("Arrow reached target and dealt damage!")
			queue_free()
