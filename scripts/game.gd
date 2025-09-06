extends Node2D
@onready var enemy_container = $EnemyContainer
@onready var spawn_timer: Timer = $Timer
var active_enemy = null
var current_letter_index: int = -1
var EnemyScene = preload("res://scenes/Orc_enemy.tscn")
var words = ["apple","bread","chair","house","light","water","plant","smile","table","train"]
var word_pool: Array = []

func _ready() -> void:
	# Initialize word pool
	word_pool = words.duplicate()
	word_pool.shuffle()
	
	# Connect timer signal and configure
	spawn_timer.wait_time = 3.0  # Spawn every 3 seconds
	spawn_timer.start()
	spawn_timer.timeout.connect(spawn_enemy)
	
func spawn_enemy():
	# Check if word pool is empty and stop spawning if needed
	if word_pool.is_empty():
		print("No more words left to assign! Stopping spawner.")
		spawn_timer.stop()  # Stop the timer to prevent further spawning attempts
		return
	
	# Wait one frame to ensure the node is fully in the scene tree
	await get_tree().process_frame
	
	
	# Get random word and remove from pool
	var random_index = randi() % word_pool.size()
	var selected_word = word_pool[random_index]
	word_pool.remove_at(random_index)
	
	# Create enemy instance
	var enemy_instance = EnemyScene.instantiate()
	enemy_instance.z_index = 2 
	# Set random position
	enemy_instance.position = Vector2(randf_range(-100, 100), randf_range(-360, -500))
	
	print("New enemy Position:",enemy_instance.position)
		# Add to enemy container
	enemy_container.add_child(enemy_instance)
	
	# Set the word/prompt for this enemy (assuming your enemy has a set_prompt method)
	enemy_instance.set_prompt(selected_word)
	
func find_new_active_enemy(typed_character: String):
	for enemy in enemy_container.get_children():
		var prompt = enemy.get_prompt()
		if prompt.length() > 0 and prompt.substr(0, 1) == typed_character:
			print("Found new enemy that starts with ", typed_character)
			active_enemy = enemy
			current_letter_index = 1
			break  # Exit loop once we find a match
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var typed_event = event as InputEventKey
		if typed_event.unicode != 0:
			var key_typed = PackedByteArray([typed_event.unicode]).get_string_from_utf8().to_lower()
			print("Key pressed:", key_typed)
			
			if active_enemy == null:
				find_new_active_enemy(key_typed)
			else:
				var prompt = active_enemy.get_prompt().to_lower()
				if current_letter_index < prompt.length():
					var next_character = prompt.substr(current_letter_index, 1)
					if key_typed == next_character:
						print("Success! Typed:", key_typed, " Expected:", next_character)
						current_letter_index += 1
						
						# Check if word is complete
						if current_letter_index >= prompt.length():
							print("Word completed:", prompt)
							current_letter_index = -1
							active_enemy.queue_free()
							active_enemy = null
					else:
						print("Wrong character! Typed:", key_typed, " Expected:", next_character)
						# Optionally reset active enemy on wrong input
