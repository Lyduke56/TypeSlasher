extends RichTextLabel

var default_text = "CURRENT SCORE: "
var wpm_prefix = "    WPM: "

# Cached: Reduce frequency of string operations and Global lookups
var cached_score: int = -1
var cached_wpm: float = -1.0
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  # Update 10 times per second instead of every frame

func _process(delta):
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		var current_score = Global.current_score
		var current_wpm = Global.get_wpm()
		
		# Only update text if values changed
		if current_score != cached_score or current_wpm != cached_wpm:
			cached_score = current_score
			cached_wpm = current_wpm
			var score_text = str(default_text, str(current_score))
			var wpm_text = str(wpm_prefix, String.num(current_wpm, 1))
			self.text = str(score_text, wpm_text)
