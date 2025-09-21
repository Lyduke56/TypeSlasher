extends Node2D

@export var green_bright: Color = Color("#39d353")   # next char
@export var green_typed:  Color = Color("#2ea043")   # already typed

@onready var word: RichTextLabel = $Word
@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") # optional

# Keep the same API/fields your Game expects:
var is_being_targeted: bool = false
var has_target: bool = false   # unused (stays still)
var target_position: Vector2   # unused

func _ready() -> void:
	# start plain text
	if word:
		word.parse_bbcode(word.text)

# --- Word API (same as orc) ---
func set_prompt(new_word: String) -> void:
	if not word:
		return
	word.text = new_word
	word.parse_bbcode(new_word)

func get_prompt() -> String:
	return word.text if word else ""

# --- Target API (noop so it never moves) ---
func set_target_position(_target: Vector2) -> void:
	# Intentionally does nothing – buff remains stationary
	target_position = global_position
	has_target = false

func set_targeted_state(targeted: bool) -> void:
	is_being_targeted = targeted
	if targeted:
		if anim:
			anim.play("idle")
		modulate = Color(0.8, 1.0, 0.8)  # slight green tint when "locked"
	else:
		modulate = Color(1, 1, 1)

func set_next_character(next_index: int) -> void:
	# If targeted (word finished) freeze visuals
	if is_being_targeted or not word:
		return

	var full_text := get_prompt()
	if next_index == -1:
		word.parse_bbcode(full_text) # reset to plain green below via color tags if you prefer
		return

	# Bounds and coloring: typed = darker green, next = bright green, remaining = plain
	next_index = clamp(next_index, 0, full_text.length())
	var typed := ""
	var nextc := ""
	var remain := ""

	if next_index > 0:
		typed = "[color=#%s]%s[/color]" % [green_typed.to_html(false), full_text.substr(0, next_index)]

	if next_index < full_text.length():
		nextc = "[color=#%s]%s[/color]" % [green_bright.to_html(false), full_text.substr(next_index, 1)]

	if next_index + 1 < full_text.length():
		remain = full_text.substr(next_index + 1)

	# Entire label appears green-ish because first two segments are green;
	# remaining is plain (you can also wrap it in a lighter green if you want all-green)
	word.parse_bbcode(typed + nextc + remain)

func play_death_animation() -> void:
	# Minimal: just disappear (you can add a “pop” animation later)
	if anim:
		anim.play("death")
		anim.animation_finished.connect(_on_anim_done)
	else:
		queue_free()

func _on_anim_done() -> void:
	if anim.animation == "death":
		queue_free()
