extends Node

var high_score = 0
var current_score: int
var previous_score: int

# --- WPM tracking ---
# We measure characters typed correctly; 5 characters = 1 word (standard WPM)
var wpm_session_started: bool = false
var wpm_start_time_seconds: float = 0.0
var wpm_paused_total_seconds: float = 0.0
var wpm_pause_started_at_seconds: float = 0.0
var wpm_correct_characters: int = 0

func wpm_reset():
	wpm_session_started = false
	wpm_start_time_seconds = 0.0
	wpm_paused_total_seconds = 0.0
	wpm_pause_started_at_seconds = 0.0
	wpm_correct_characters = 0

func wpm_start_if_needed():
	if not wpm_session_started:
		wpm_session_started = true
		wpm_start_time_seconds = Time.get_ticks_msec() / 1000.0
		wpm_paused_total_seconds = 0.0
		wpm_pause_started_at_seconds = 0.0
		wpm_correct_characters = 0

func wpm_on_pause():
	# Called when game pauses
	if wpm_session_started and wpm_pause_started_at_seconds == 0.0:
		wpm_pause_started_at_seconds = Time.get_ticks_msec() / 1000.0

func wpm_on_resume():
	# Called when game resumes
	if wpm_session_started and wpm_pause_started_at_seconds > 0.0:
		var now_s = Time.get_ticks_msec() / 1000.0
		wpm_paused_total_seconds += max(0.0, now_s - wpm_pause_started_at_seconds)
		wpm_pause_started_at_seconds = 0.0

func wpm_note_correct_characters(num_chars: int = 1):
	# Record correctly typed characters
	wpm_start_if_needed()
	wpm_correct_characters += max(0, num_chars)

func get_wpm() -> float:
	if not wpm_session_started:
		return 0.0
	var now_s = Time.get_ticks_msec() / 1000.0
	var elapsed_s = max(0.0, now_s - wpm_start_time_seconds)
	# Subtract currently paused span if in pause
	var effective_paused = wpm_paused_total_seconds
	if wpm_pause_started_at_seconds > 0.0:
		effective_paused += max(0.0, now_s - wpm_pause_started_at_seconds)
	var active_seconds = max(0.0, elapsed_s - effective_paused)
	if active_seconds <= 0.0:
		return 0.0
	var words_typed = float(wpm_correct_characters) / 5.0
	return words_typed / (active_seconds / 60.0)
