extends CanvasLayer  # Or CanvasLayer, depending on your root

@onready var score_list_container = $MarginContainer/MainLayout/ScrollContainer/ScoreList
@onready var prev_button = $MarginContainer/NavContainer/PrevButton
@onready var next_button = $MarginContainer/NavContainer/NextButton
@onready var page_label = $MarginContainer/NavContainer/PageLabel
var score_row_scene = preload("res://Scenes/ScoreRow.tscn") # Adjust path if needed

var current_page: int = 0
const SCORES_PER_PAGE: int = 10

func _ready():
	Global.load_scores()
	update_board()
	prev_button.connect("pressed", Callable(self, "_on_prev_pressed"))
	next_button.connect("pressed", Callable(self, "_on_next_pressed"))

func update_board():
	# 1. Clear existing rows
	for child in score_list_container.get_children():
		child.queue_free()

	# 2. Calculate page slice
	var start_index = current_page * SCORES_PER_PAGE
	var end_index = min(start_index + SCORES_PER_PAGE, Global.leaderboard_scores.size())

	# 3. Loop through slice and create rows
	var rank = start_index + 1
	for i in range(start_index, end_index):
		var entry = Global.leaderboard_scores[i]
		var new_row = score_row_scene.instantiate()
		score_list_container.add_child(new_row)

		# Pass data to the row
		new_row.set_score_data(rank, entry["name"], entry["time"], entry["score"])

		# Optional: Alternate colors for readability
		if rank % 2 == 0:
			new_row.modulate = Color(0.9, 0.9, 0.9, 1)

		rank += 1

	# 4. Update page label
	page_label.text = str(current_page + 1)

	# 5. Update button states
	prev_button.disabled = (current_page == 0)
	var max_page = ceil(float(Global.leaderboard_scores.size()) / SCORES_PER_PAGE) - 1
	next_button.disabled = (current_page >= max_page)

func _on_prev_pressed():
	if current_page > 0:
		current_page -= 1
		update_board()

func _on_next_pressed():
	var max_page = ceil(float(Global.leaderboard_scores.size()) / SCORES_PER_PAGE) - 1
	if current_page < max_page:
		current_page += 1
		update_board()

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
