extends Node2D

@onready var enemy_container =$EnemyContainer

var active_enemy = null
var current_letter_index: int = -1


func _find_new_active_enemy(typed_character: String):
	for enemy in enemy_container.get_children():
		var prompt = enemy.get_prompt()
		var next_character = prompt.substr(0,1)
		if prompt.substr(0, 1) == typed_character:
			print("Found new enemy that starts with ", next_character)
			active_enemy = enemy
			current_letter_index = 1 

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var typed_event = event as InputEventKey
		if typed_event.unicode != 0:
			var key_typed = PackedByteArray([typed_event.unicode]).get_string_from_utf8()
			print("Key pressed:", key_typed)

			if active_enemy == null:
				_find_new_active_enemy(key_typed)
			else:
				var prompt = active_enemy.get_prompt()
				var next_character = prompt.substr(current_letter_index, 1)
				if key_typed == next_character:
					print("Success!")
					current_letter_index += 1
					if current_letter_index == prompt.length():
						current_letter_index = -1
						active_enemy.queue_free()
						active_enemy = null


func _ready() -> void:
	pass
	
	

func _process(delta: float) -> void:
	pass
	
