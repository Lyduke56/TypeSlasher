extends Control

@onready var menu_panel: NinePatchRect = $Menu
@onready var info_panel: NinePatchRect = $Information
@onready var settings_panel: NinePatchRect = $Settings
@onready var continue_button: Button = $Menu/VBoxContainer/Continue
@onready var info_button: Button = $Menu/VBoxContainer/Information
@onready var settings_button: Button = $Menu/VBoxContainer/Settings
@onready var quit_button: Button = $Menu/VBoxContainer/Quit
@onready var description_panel: NinePatchRect = $Information/Description
@onready var close_button: Button = $Information/Close
@onready var settings_close_button: Button = $Settings/Close

signal request_resume_game

func _ready() -> void:
	visible = false
	menu_panel.visible = true
	info_panel.visible = false
	if settings_panel:
		settings_panel.visible = false

	continue_button.pressed.connect(_on_continue_pressed)
	info_button.pressed.connect(_on_information_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	close_button.pressed.connect(_on_close_information_pressed)
	if settings_close_button:
		settings_close_button.pressed.connect(_on_close_settings_pressed)

	# Connect all slot instances to selection handler
	var grid := $Information/GridContainer
	for slot in grid.get_children():
		if slot.has_signal("slot_selected"):
			slot.slot_selected.connect(_on_slot_selected)

func _on_continue_pressed() -> void:
	emit_signal("request_resume_game")

func _on_information_pressed() -> void:
	menu_panel.visible = false
	info_panel.visible = true
	if settings_panel:
		settings_panel.visible = false

func _on_settings_pressed() -> void:
	menu_panel.visible = false
	info_panel.visible = false
	if settings_panel:
		settings_panel.visible = true

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_close_information_pressed() -> void:
	# Close Information panel and re-open the main menu VBox
	info_panel.visible = false
	if settings_panel:
		settings_panel.visible = false
	menu_panel.visible = true

func _on_close_settings_pressed() -> void:
	# Close Settings panel and re-open the main menu VBox
	if settings_panel:
		settings_panel.visible = false
	info_panel.visible = false
	menu_panel.visible = true

func _on_slot_selected(slot) -> void:
	# Update description panel from slot's data
	var item: Dictionary = {}
	if slot.has_method("get_item"):
		item = slot.get_item()
	var title_node := description_panel.get_node("Title")
	var desc_node := description_panel.get_node("Description")
	var icon_node := description_panel.get_node("Icon")
	if title_node and item.has("title"):
		title_node.text = String(item["title"])
	if desc_node and item.has("description"):
		desc_node.text = String(item["description"])
	if icon_node and item.has("icon") and item["icon"] is Texture2D:
		icon_node.texture = item["icon"]
