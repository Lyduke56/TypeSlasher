extends Node2D

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")

@export var speed: float = 0.5

var words = ["apple","bread","chair","house","light","water","plant","smile","table","train"]
@onready var word: RichTextLabel = $Word
@onready var prompt = $Word
@onready var prompt_text = prompt.text



func _ready() -> void:
	word.text = RandWordPicker()
	
	
func _process(delta: float) -> void: 
	pass
	
func RandWordPicker(): 
	var random_index = randi_range(0,words.size() - 1)
	var chosen_word = words[random_index]
	return chosen_word

# --- Set word from spawner ---
func set_prompt(new_word: String) -> void:
	word.text = new_word  # keep a clean text for reference
	word.parse_bbcode(new_word)  # start with plain text

func get_prompt() -> String:
	return word.text
	

func set_next_character(next_character_index: int):
	var full_text: String = get_prompt()

	var typed_part = ""
	var next_char_part = ""
	var remaining_part = ""
	
	# already typed → green
	if next_character_index > 0:
		typed_part = get_bbcode_color_tag(green) + full_text.substr(0, next_character_index) + get_bbcode_end_color_tag()

	# next character → blue
	if next_character_index < full_text.length():
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

func _physics_process(delta: float) -> void:
	global_position.y += speed 
