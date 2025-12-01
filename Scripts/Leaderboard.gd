extends CanvasLayer

# CORRECTED PATHS based on your Leaderboard.tscn file
@onready var ScoreList = $Control/BoardPanel/VBoxContainer/ScrollContainer/ScoreList
@onready var PageLabel = $Control/BoardPanel/VBoxContainer/NavContainer/PageLabel
@onready var PrevButton = $Control/BoardPanel/VBoxContainer/NavContainer/PrevButton
@onready var NextButton = $Control/BoardPanel/VBoxContainer/NavContainer/NextButton
# Note: CloseButton is inside TopBar in your scene, not directly in the container
@onready var CloseButton = $Close

var score_row_scene = preload("res://Scenes/ScoreRow.tscn")

func _ready():
	# Connect signals
	PrevButton.pressed.connect(_on_prev_pressed)
	NextButton.pressed.connect(_on_next_pressed)
	CloseButton.pressed.connect(_on_close_pressed)

	Global.load_scores()
	update_display()

func update_display():
	# First, remove all existing children in ScoreList (to clear dummy rows).
	for child in ScoreList.get_children():
		child.queue_free()

	# Check Global.leaderboard_scores.
	if Global.leaderboard_scores.is_empty():
		var label = Label.new()
		label.text = "No Scores Yet"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ScoreList.add_child(label)
		PrevButton.disabled = true
		NextButton.disabled = true
	else:
		# If it has data: Calculate start/end indices for the top 10 (Page 0).
		var end_index = min(10, Global.leaderboard_scores.size())

		# Loop through the data slice.
		for rank in range(1, end_index + 1):
			var entry = Global.leaderboard_scores[rank - 1]
			# Instantiate ScoreRow, add it to ScoreList
			var new_row = score_row_scene.instantiate()
			ScoreList.add_child(new_row)
			# call set_score_data(rank, name, time, score)
			new_row.set_score_data(rank, entry["name"], entry["time"], entry["score"])

		# Update PageLabel to show the current page.
		PageLabel.text = "1"

		# Since we are just showing top 10 for now, disable pagination
		PrevButton.disabled = true
		NextButton.disabled = true

func _on_prev_pressed():
	pass

func _on_next_pressed():
	pass

func _on_close_pressed():
	queue_free()
