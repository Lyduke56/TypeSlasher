extends Control

func ItemPopup(slot: Rect2i, item_data: BuffData):

	%ItemPopup/VBoxContainer/Label.text = item_data.buff_name
	%ItemPopup/VBoxContainer/Label2.text = item_data.description

	var mouse_pos = get_viewport().get_mouse_position()
	var correction

	if mouse_pos.x <= get_viewport_rect().size.x/2:
		correction = Vector2i(slot.size.x, 0)
	else:
		correction = -Vector2i(%ItemPopup.size.x, 0)

	%ItemPopup.popup(Rect2i(slot.position + correction, %ItemPopup.size))

func HideItemPopup():
	%ItemPopup.hide()
