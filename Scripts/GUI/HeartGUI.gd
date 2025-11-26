extends Panel

@onready var background = $Background
@onready var foreground = $Foreground

func update(whole: bool):
	# 1. Ensure Background (Empty Heart) is ALWAYS visible
	if background:
		background.visible = true

	# 2. Toggle Foreground (Full Heart) based on health status
	if foreground:
		foreground.visible = whole
