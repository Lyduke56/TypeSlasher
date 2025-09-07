# WordDatabase.gd (your helper script)
extends RefCounted
class_name WordDatabase

static var word_database = {}

# Load the JSON data
static func load_word_database():
	var file = FileAccess.open("res://data/words.json", FileAccess.READ)
	if file == null:
		print("Error: Could not open words.json")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Error parsing JSON: ", json.error_string)
		return
	
	word_database = json.data
	print("Word database loaded successfully!")

# Get words from specific categories
static func get_random_easy_word():
	var easy_words = word_database["easy"]
	return easy_words[randi() % easy_words.size()]

static func get_random_sentence():
	var sentences = word_database["sentence"]
	return sentences[randi() % sentences.size()]

# Get all words from a category
static func get_category_words(category: String):
	if category in word_database:
		return word_database[category]
	else:
		print("Category not found: ", category)
		return []

# Generic function to get random word from any category
static func get_random_word(category: String):
	if category in word_database and word_database[category].size() > 0:
		var words = word_database[category]
		return words[randi() % words.size()]
	else:
		print("Category not found or empty: ", category)
		return ""
