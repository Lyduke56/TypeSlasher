extends Area2D

# Typing mechanic
var prompt: String = ""
var current_index: int = 0
var is_being_targeted: bool = false

@onready var text_label: RichTextLabel = $RichTextLabel  # assuming it's there

func _ready() -> void:
	pass

func set_prompt(word: String) -> void:
	prompt = word.to_lower()
	current_index = 0
	is_being_targeted = false
	text_label.text = _format_prompt(prompt, current_index)
	text_label.visible = true

func get_prompt() -> String:
	return prompt

func set_next_character(index: int) -> void:
	current_index = index
	text_label.text = _format_prompt(prompt, current_index)

func _format_prompt(word: String, typed_index: int) -> String:
	var green_part = word.substr(0, typed_index)
	var red_part = ""
	if typed_index < word.length():
		red_part = word.substr(typed_index, 1)
	var remaining = ""
	if typed_index < word.length() - 1:
		remaining = word.substr(typed_index + 1)
	return "[color=green]" + green_part + "[/color][color=red]" + red_part + "[/color]" + remaining

func set_targeted_state(targeted: bool) -> void:
	is_being_targeted = targeted
