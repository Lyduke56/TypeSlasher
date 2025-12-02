extends CanvasLayer

# Path references
@onready var ScoreList = $Control/BoardPanel/VBoxContainer/ScrollContainer/ScoreList
@onready var PageLabel = $Control/BoardPanel/VBoxContainer/NavContainer/PageLabel
@onready var PrevButton = $Control/BoardPanel/VBoxContainer/NavContainer/PrevButton
@onready var NextButton = $Control/BoardPanel/VBoxContainer/NavContainer/NextButton
@onready var CloseButton = $Close

var score_row_scene = preload("res://Scenes/ScoreRow.tscn")

# --- PAGINATION VARIABLES ---
var items_per_page: int = 10
var current_page: int = 0
var total_pages: int = 0

func _ready():
	# Connect signals
	PrevButton.pressed.connect(_on_prev_pressed)
	NextButton.pressed.connect(_on_next_pressed)
	CloseButton.pressed.connect(_on_close_pressed)

	# Load fresh data from Global
	Global.load_scores()

	# Calculate total pages immediately
	calculate_total_pages()

	update_display()

func calculate_total_pages():
	var total_count = Global.leaderboard_scores.size()
	if total_count == 0:
		total_pages = 1
	else:
		# ceil() rounds up (e.g., 11 items / 10 = 1.1 -> 2 pages)
		total_pages = ceil(float(total_count) / float(items_per_page))

func update_display():
	# 1. Clear current list
	for child in ScoreList.get_children():
		child.queue_free()

	var all_scores = Global.leaderboard_scores

	if all_scores.is_empty():
		var label = Label.new()
		label.text = "No Scores Yet"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ScoreList.add_child(label)

		PageLabel.text = "Page 1 / 1"
		PrevButton.disabled = true
		NextButton.disabled = true
		return

	# 2. Safety check for current page
	if current_page >= total_pages:
		current_page = max(0, total_pages - 1)

	# 3. Calculate Start and End Index for slicing the array
	var start_index = current_page * items_per_page
	var end_index = min(start_index + items_per_page, all_scores.size())

	# 4. Loop only through the specific slice for this page
	for i in range(start_index, end_index):
		var entry = all_scores[i]
		var row = score_row_scene.instantiate()
		ScoreList.add_child(row)

		# Rank is index + 1
		# We use safe .get() to avoid crashing if data is missing
		var rank = i + 1
		var p_name = entry.get("name", "Unknown")
		var p_time = entry.get("time", "--:--")
		var p_score = entry.get("score", 0)

		row.set_score_data(rank, p_name, p_time, int(p_score))

	# 5. Update UI Controls
	PageLabel.text = "Page %d / %d" % [current_page + 1, total_pages]

	# Disable Prev if on first page
	PrevButton.disabled = (current_page == 0)

	# Disable Next if on last page
	NextButton.disabled = (current_page >= total_pages - 1)

func _on_prev_pressed():
	if current_page > 0:
		current_page -= 1
		update_display()

func _on_next_pressed():
	if current_page < total_pages - 1:
		current_page += 1
		update_display()

func _on_close_pressed():
	queue_free()
