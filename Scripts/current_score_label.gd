extends RichTextLabel

var default_text = "CURRENT SCORE: "
var wpm_prefix = "    WPM: "

func _process(delta):
	var score_text = str(default_text, str(Global.current_score))
	var wpm_val: float = Global.get_wpm()
	var wpm_text = str(wpm_prefix, String.num(wpm_val, 1))
	self.text = str(score_text, wpm_text)
