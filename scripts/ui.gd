extends Control

const EnemyData = preload("res://Scripts/EnemyData.gd")

signal request_resume_game
@onready var menu: NinePatchRect = $Menu
@onready var information: NinePatchRect = $Information
@onready var settings: NinePatchRect = $Settings
@onready var buff: NinePatchRect = $Buff

@export var description: NinePatchRect

func _ready():
	defaultsetup()
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

	# Connect NG+ button
	var ng_plus_button = get_node_or_null("Settings/NG+Button")
	if ng_plus_button:
		ng_plus_button.toggled.connect(_on_ng_plus_toggled)

	# Connect slots in information panel
	var grid_container = get_node_or_null("Information/GridContainer")
	if grid_container:
		for slot in grid_container.get_children():
			if slot.has_signal("slot_selected"):
				slot.connect("slot_selected", Callable(self, "_on_slot_selected"))

func defaultsetup():
	menu.visible = true
	information.visible = false
	settings.visible = false
	buff.visible = false


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
		
		# Update NG+ button state
		var ng_plus_button = get_node_or_null("Settings/NG+Button")
		if ng_plus_button:
			ng_plus_button.button_pressed = Global.ng_plus_enabled
			ng_plus_button.disabled = not Global.ng_plus_unlocked

func _on_quit_pressed():
	# Go to main menu scene instead of quitting
	get_tree().paused = false  # Unpause before changing scenes

		# --- RESET BUFFS START ---
	# Reset all buff stacks so they don't carry over to the next game
	Global.shield_buff_stacks = 0
	Global.is_shield_ready = false
	if Global.shield_timer: Global.shield_timer.stop()

	Global.sword_buff_stacks = 0
	Global.sword_heal_chance = 0

	Global.freeze_buff_stacks = 0
	Global.freeze_activation_chance = 0
	if Global.freeze_timer: Global.freeze_timer.stop()

	Global.buff_stacks_changed.emit()
	# --- RESET BUFFS END ---

	Global.player_max_health = 3  # Default max health, increases permanently
	Global.player_current_health = 3  # Current health, resets to max when entering dungeon

	# Reset dungeon progress for future gameplay
	DungeonProgress.reset_progress()
	DungeonProgress.current_area = 1

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
	print("Description panel children: ", desc_panel.get_children().map(func(c): return str(c.name) + " (" + str(c.get_class()) + ")"))
	var title_node = desc_panel.get_node("Title")
	if title_node:
		title_node.text = data.name
	var icon_node = desc_panel.get_node("Icon")
	print("Icon node: ", icon_node)
	if icon_node and icon_node.get_children():
		print("Icon children: ", icon_node.get_children().map(func(c): return str(c.name) + " (" + str(c.get_class()) + ")"))
	if icon_node:
		# Try to find AnimatedSprite2D directly under desc_panel or under Icon
		var animated_sprite: AnimatedSprite2D = null
		if icon_node is AnimatedSprite2D:
			animated_sprite = icon_node
		else:
			# Look under Icon if it's a container
			if icon_node.is_class("Control") or icon_node is TextureRect or icon_node is Node2D:
				for child in icon_node.get_children():
					if child is AnimatedSprite2D:
						animated_sprite = child
						print("Found AnimatedSprite2D child: ", child.name)
						break
		# Or look directly under desc_panel for AnimatedSprite2D
		if not animated_sprite:
			for child in desc_panel.get_children():
				if child is AnimatedSprite2D and child.name != "Icon":  # exclude if Icon is not animated
					animated_sprite = child
					print("Found AnimatedSprite2D under desc_panel: ", child.name)
					break
		if animated_sprite:
			if data.sprite_frames:
				animated_sprite.sprite_frames = data.sprite_frames
				print("Setting sprite_frames on AnimatedSprite2D: ", data.sprite_frames)
				var anim_list = data.sprite_frames.get_animation_names()
				print("Available animations: ", anim_list)
				var anim_to_play = data.animation_name if data.animation_name != "" else (anim_list[0] if anim_list.size() > 0 else "")
				if anim_to_play:
					animated_sprite.animation = anim_to_play
					print("Setting animation to: ", anim_to_play)
					animated_sprite.play()
					print("Is playing after play(): ", animated_sprite.is_playing())
				# Offset NightBorne sprite to the top due to off-centered loading
				if data.name == "NightBorne":
					animated_sprite.offset = Vector2(0, -16)  # Adjust Y offset to move sprite upward
				else:
					animated_sprite.offset = Vector2(0, 0)  # Reset offset for other enemies
			else:
				animated_sprite.stop()
		# Only set static texture if no animated sprite and Icon is TextureRect - but ideally animated should always have sprite_frames
		elif icon_node is TextureRect:
			icon_node.texture = data.static_sprite
			print("Falling back to static texture on TextureRect")
	var desc_node = desc_panel.get_node("Description")
	if desc_node:
		desc_node.text = data.description

func _on_ng_plus_toggled(toggled_on: bool):
	if not Global.ng_plus_unlocked:
		return  # Safety check - don't allow toggling if not unlocked
	Global.ng_plus_enabled = toggled_on
	Global.save_ng_plus()
	print("NG+ enabled: ", toggled_on)
