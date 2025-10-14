extends Node2D

# Load WordDatabase at dungeon level so rooms can access it
func _ready() -> void:
	WordDatabase.load_word_database()
	print("WordDatabase loaded for dungeon Area 1 Var 1")
