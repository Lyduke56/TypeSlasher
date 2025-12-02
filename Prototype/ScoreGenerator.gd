extends SceneTree

func _init():
	print("--- STARTING FAKE SCORE GENERATION ---")

	# List of fake names to pick from
	var names = ["DragonSlayer", "Knight", "ElfRogue", "Wizard101", "SpeedRunner", "DevTeam", "Tester", "Guest"]

	# Generate 15 fake scores
	for i in range(15):
		var random_name = names.pick_random() + str(randi() % 99)
		var random_score = randi_range(500, 50000)

		# Generate a fake time string (e.g., "03:45")
		var minutes = randi_range(1, 15)
		var seconds = randi_range(0, 59)
		var time_str = "%02d:%02d" % [minutes, seconds]

		# Call your existing Global function
		# Note: We access the singleton via the root since this script is running standalone
		var global = root.get_node("/root/Global")
		if global:
			global.add_score(random_name, time_str, random_score)
		else:
			print("Error: Could not find Global singleton. Run this scene normally inside the game loop instead.")
			quit()
			return

	print("--- GENERATION COMPLETE. CHECK LEADERBOARD ---")
	quit() # Close the window automatically
