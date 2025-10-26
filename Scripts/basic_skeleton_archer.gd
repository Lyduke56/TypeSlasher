extends Node2D

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")

@onready var anim = $AnimatedSprite2D
@onready var word: RichTextLabel = $Word
@onready var prompt = $Word
@onready var prompt_text = prompt.text
@onready var area: Area2D = $Area2D
@onready var shoot_timer: Timer = $ShootTimer

var target_position: Vector2
var has_target: bool = false
var is_being_targeted: bool = false
var has_reached_target: bool = false
var target_node: Node2D

var points_for_kill = 150
var arrow_scene = preload("res://Scenes/Enemies/arrow.tscn")

func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	if anim:
		anim.animation_finished.connect(_on_animation_finished)
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	# The archer should start shooting as soon as it is ready
	has_reached_target = true
	target_node = get_node("/root/Main/Player")
	shoot_timer.wait_time = 5.0  # Shoot every 5 seconds
	shoot_timer.start()
	pass

func _process(delta: float) -> void:
	pass

func set_prompt(new_word: String) -> void:
	word.text = new_word
	word.parse_bbcode(new_word)

func get_prompt() -> String:
	return word.text

func set_target_position(target: Vector2) -> void:
	# This function is no longer needed for the archer
	pass

func set_next_character(next_character_index: int):
	if is_being_targeted:
		return

	if not is_instance_valid(self):
		return

	var full_text: String = get_prompt()

	if next_character_index < -1 or next_character_index > full_text.length():
		print("Warning: Invalid character index: ", next_character_index)
		return

	var typed_part = ""
	var next_char_part = ""
	var remaining_part = ""

	if next_character_index > 0:
		typed_part = get_bbcode_color_tag(green) + full_text.substr(0, next_character_index) + get_bbcode_end_color_tag()

	if next_character_index >= 0 and next_character_index < full_text.length():
		next_char_part = get_bbcode_color_tag(blue) + full_text.substr(next_character_index, 1) + get_bbcode_end_color_tag()

	if next_character_index + 1 < full_text.length():
		remaining_part = full_text.substr(next_character_index + 1)

	word.parse_bbcode(typed_part + next_char_part + remaining_part)

func get_bbcode_color_tag(color: Color) -> String:
	return "[color=#" + color.to_html(false) + "]"

func get_bbcode_end_color_tag() -> String:
	return "[/color]"

func set_targeted_state(targeted: bool):
	is_being_targeted = targeted
	if targeted:
		if anim:
			anim.play("idle")
		modulate = Color.GRAY
	else:
		modulate = Color.WHITE

func play_death_animation():
	Global.current_score += points_for_kill
	Global.on_enemy_killed()
	queue_free()

func _on_damage_animation_finished():
	if anim.animation == "damaged":
		if anim.animation_finished.is_connected(_on_death_animation_finished):
			anim.animation_finished.disconnect(_on_death_animation_finished)

		anim.animation_finished.connect(_on_death_animation_finished, CONNECT_ONE_SHOT)
		anim.play("death")
		print("Enemy death animation started")

func _on_death_animation_finished():
	if anim.animation == "death":
		Global.current_score += points_for_kill
		Global.on_enemy_killed()
		queue_free()

func _on_body_entered(body: Node2D):
	# This function is no longer needed as the archer does not move
	pass

func _on_shoot_timer_timeout():
	if not is_being_targeted and anim:
		anim.play("skeleton_archer_attack")

func _on_animation_finished():
	if anim and (anim.animation == "death" or anim.animation == "damaged" or is_being_targeted):
		return

	if anim and anim.animation == "skeleton_archer_attack":
		shoot_arrow()
		anim.play("idle")

func shoot_arrow():
	var arrow = arrow_scene.instantiate()
	get_parent().add_child(arrow)
	arrow.global_position = global_position
	arrow.set_target(target_node)
	var word = WordDatabase.get_random_word("easy")
	arrow.set_prompt(word)

func _physics_process(delta: float) -> void:
	if is_being_targeted:
		if anim and anim.animation != "death" and anim.animation != "damaged":
			anim.play("idle")
		return

	if anim and anim.animation != "skeleton_archer_attack" and anim.animation != "death" and anim.animation != "damaged":
		anim.play("idle")
