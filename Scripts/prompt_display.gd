extends CanvasLayer

@onready var word_label: RichTextLabel = $Word
var blue: Color = Color("#4682b4")
var green: Color = Color("#639765")
var red: Color = Color("#a65455")
var yellow: Color = Color("#f8eecc")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if word_label:
		word_label.bbcode_enabled = true

func update_prompt_display(full_text: String, current_index: int) -> void:
	"""Update the prompt display to show the current typing progress"""
	if not word_label:
		return

	var typed_part = ""
	var next_char_part = ""
	var remaining_part = ""

	# Typed part (green)
	if current_index > 0:
		typed_part = "[color=#" + yellow.to_html(false) + "]" + full_text.substr(0, current_index) + "[/color]"

	# Next character (blue)
	if current_index >= 0 and current_index < full_text.length():
		next_char_part = "[color=#" + blue.to_html(false) + "]" + full_text.substr(current_index, 1) + "[/color]"

	# Remaining part (normal)
	if current_index + 1 < full_text.length():
		remaining_part = full_text.substr(current_index + 1)

	word_label.text = typed_part + next_char_part + remaining_part
	visible = true

func clear_prompt_display() -> void:
	"""Hide the prompt display when there's no active enemy"""
	word_label.text = ""
	visible = false
