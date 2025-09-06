extends Node2D

#Make a generator function and connect it to the rich text label word.
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

func set_prompt(new_word: String) -> void:
	word.text = new_word

func get_prompt() -> String:
	return word.text
