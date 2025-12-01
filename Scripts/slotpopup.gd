extends PanelContainer

func _on_mouse_entered() -> void:
	Popups.ItemPopup(Rect2i(Vector2i(global_position), Vector2i(size)),null)

func _on_mouse_exited() -> void:
	Popups.HideItemPopup()
