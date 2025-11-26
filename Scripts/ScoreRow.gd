extends HBoxContainer

# Assign these in the Inspector or ensure node names match exactly
@onready var rank_label = $Rank
@onready var name_label = $Name
@onready var time_label = $Time
@onready var score_label = $Score

func set_score_data(rank_num: int, player_name: String, time_str: String, score_num: int):
	rank_label.text = str(rank_num)
	name_label.text = player_name
	time_label.text = time_str
	score_label.text = str(score_num)
