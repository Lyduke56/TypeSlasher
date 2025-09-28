extends Control

signal request_resume_game

@export var description: NinePatchRect

func _ready():
	# Connect the main menu buttons
	var continue_button = get_node_or_null("Menu/VBoxContainer/Continue")
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)

	var information_button = get_node_or_null("Menu/VBoxContainer/Information")
	if information_button:
		information_button.pressed.connect(_on_information_pressed)

	var settings_button = get_node_or_null("Menu/VBoxContainer/Settings")
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)

	var quit_button = get_node_or_null("Menu/VBoxContainer/Quit")
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	# Connect the close buttons for panels
	var info_close_button = get_node_or_null("Information/Close")
	if info_close_button:
		info_close_button.pressed.connect(_on_info_close_pressed)

	var settings_close_button = get_node_or_null("Settings/Close")
	if settings_close_button:
		settings_close_button.pressed.connect(_on_settings_close_pressed)

	# Connect slots in information panel
	var grid_container = get_node_or_null("Information/GridContainer")
	if grid_container:
		for slot in grid_container.get_children():
			if slot.has_signal("slot_selected"):
				slot.connect("slot_selected", Callable(self, "_on_slot_selected"))


func _on_continue_pressed():
	request_resume_game.emit()

func _on_information_pressed():
	# Hide main menu and show information panel
	var main_menu = get_node_or_null("Menu")
	var info_panel = get_node_or_null("Information")
	if main_menu and info_panel:
		main_menu.visible = false
		info_panel.visible = true

func _on_settings_pressed():
	# Hide main menu and show settings panel
	var main_menu = get_node_or_null("Menu")
	var settings_panel = get_node_or_null("Settings")
	if main_menu and settings_panel:
		main_menu.visible = false
		settings_panel.visible = true

func _on_quit_pressed():
	# Go to main menu scene instead of quitting
	get_tree().change_scene_to_file("res://Scenes/Menu.tscn")

func _on_info_close_pressed():
	# Hide information panel and show main menu
	var main_menu = get_node_or_null("Menu")
	var info_panel = get_node_or_null("Information")
	if main_menu and info_panel:
		info_panel.visible = false
		main_menu.visible = true

func _on_settings_close_pressed():
	# Hide settings panel and show main menu
	var main_menu = get_node_or_null("Menu")
	var settings_panel = get_node_or_null("Settings")
	if main_menu and settings_panel:
		settings_panel.visible = false
		main_menu.visible = true

func _on_slot_selected(data: EnemyData):
	set_description(data)

func set_description(data: EnemyData):
	var desc_panel = $Information/Description
	if not desc_panel or not data:
		return
	var title_node = desc_panel.get_node("Title")
	if title_node:
		title_node.text = data.name
	var icon_node = desc_panel.get_node("Icon")
	if icon_node:
		if icon_node is AnimatedSprite2D:
			if data.sprite_frames:
				icon_node.sprite_frames = data.sprite_frames
				icon_node.animation = data.animation_name if data.animation_name else "idle "
				icon_node.play()
			else:
				icon_node.stop()
		elif icon_node is TextureRect:
			icon_node.texture = data.static_sprite
	var desc_node = desc_panel.get_node("Description")
	if desc_node:
		desc_node.text = data.description
