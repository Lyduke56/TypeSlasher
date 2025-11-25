extends Control

# Main active buffs scene controller - manages visibility of BuffSlot children
var buff_slots: Array = []

func _ready():
	print("ActiveBuffs: _ready() called")
	await get_tree().process_frame
	setup_buff_slot_references()
	update_buff_visibility()

func setup_buff_slot_references():
	"""Get references to all BuffSlot children in order (right to left)"""
	print("ActiveBuffs: Setting up buff slot references")
	buff_slots = []
	var grid_container = get_node_or_null("NinePatchRect/GridContainer")

	print("ActiveBuffs: Grid container found: ", grid_container != null)

	if grid_container:
		var buff_slot_5 = grid_container.get_node_or_null("BuffSlot5")
		var buff_slot_4 = grid_container.get_node_or_null("BuffSlot4")
		var buff_slot_3 = grid_container.get_node_or_null("BuffSlot3")
		var buff_slot_2 = grid_container.get_node_or_null("BuffSlot2")
		var buff_slot = grid_container.get_node_or_null("BuffSlot")

		print("ActiveBuffs: BuffSlot5 found: ", buff_slot_5 != null)
		print("ActiveBuffs: BuffSlot4 found: ", buff_slot_4 != null)
		print("ActiveBuffs: BuffSlot3 found: ", buff_slot_3 != null)
		print("ActiveBuffs: BuffSlot2 found: ", buff_slot_2 != null)
		print("ActiveBuffs: BuffSlot found: ", buff_slot != null)

		if buff_slot_5: buff_slots.append(buff_slot_5)
		if buff_slot_4: buff_slots.append(buff_slot_4)
		if buff_slot_3: buff_slots.append(buff_slot_3)
		if buff_slot_2: buff_slots.append(buff_slot_2)
		if buff_slot: buff_slots.append(buff_slot)

	print("ActiveBuffs: Found ", buff_slots.size(), " buff slots")

func update_buff_visibility():
	"""Update visibility of buff slots based on active buffs from global.gd"""
	print("ActiveBuffs: Updating buff visibility")

	# Check Global availability
	print("ActiveBuffs: Global exists: ", Global != null)
	if Global:
		print("ActiveBuffs: Shield stacks: ", Global.shield_buff_stacks)
		print("ActiveBuffs: Sword stacks: ", Global.sword_buff_stacks)
		print("ActiveBuffs: Freeze stacks: ", Global.freeze_buff_stacks)
		print("ActiveBuffs: Max health: ", Global.player_max_health)

	var active_buffs = get_active_buffs()
	print("ActiveBuffs: Active buffs: ", active_buffs.size())

	# Hide all slots initially
	for slot in buff_slots:
		if slot:
			slot.visible = false

	# Show slots for active buffs (right to left)
	for i in range(min(active_buffs.size(), buff_slots.size())):
		var slot = buff_slots[i]
		var buff_info = active_buffs[i]
		if slot:
			slot.visible = true
			print("ActiveBuffs: Setting slot ", i, " visible with stacks: ", buff_info.stacks)
			update_buff_slot_content(slot, buff_info.stacks, buff_info.icon)
		else:
			print("ActiveBuffs: Slot ", i, " is null!")

	# Hide entire scene if no buffs are active
	var any_buff_visible = false
	for slot in buff_slots:
		if slot and slot.visible:
			any_buff_visible = true
			break

	visible = any_buff_visible
	print("ActiveBuffs: Scene visible: ", visible)

func get_active_buffs() -> Array:
	"""Get list of active buffs from global.gd"""
	var active_buffs = []

	# Health buff - show if max health > 3 (since 3 is default)
	var health_stacks = max(0, Global.player_max_health - 3)
	if health_stacks > 0:
		active_buffs.append({
			"stacks": health_stacks,
			"icon": preload("res://Assets/Sprites/GUI/Buff_HealthPotion.png")
		})

	# Shield buff
	if Global.shield_buff_stacks > 0:
		active_buffs.append({
			"stacks": Global.shield_buff_stacks,
			"icon": preload("res://Assets/Sprites/GUI/Buff_Shield.png")
		})

	# Sword buff
	if Global.sword_buff_stacks > 0:
		active_buffs.append({
			"stacks": Global.sword_buff_stacks,
			"icon": preload("res://Assets/Sprites/GUI/Buff_sword.png")
		})

	# Freeze/Vine buff
	if Global.freeze_buff_stacks > 0:
		active_buffs.append({
			"stacks": Global.freeze_buff_stacks,
			"icon": preload("res://Assets/Sprites/GUI/Buff_Vines.png")
		})

	return active_buffs

func update_buff_slot_content(slot: Control, stacks: int, icon: Texture2D):
	"""Update the content of a buff slot (icon and stack count)"""
	if not slot:
		return

	print("ActiveBuffs: Updating slot content, stacks: ", stacks)
	print("ActiveBuffs: Icon texture exists: ", icon != null)

	# Update ICON texture (Z index 2 in ActiveBuffSlot) - this is the key fix!
	var icon_node = slot.get_node_or_null("ICON")
	print("ActiveBuffs: ICON node found: ", icon_node != null)

	if icon_node and icon_node is TextureRect:
		icon_node.texture = icon
		print("ActiveBuffs: Set icon texture")
	else:
		print("ActiveBuffs: ICON node is not a TextureRect or not found")

	# Update stack count - look for Label
	var stack_label = slot.get_node_or_null("StackLabel")
	if not stack_label:
		stack_label = slot.get_node_or_null("Stack Counter")
		if not stack_label:
			# Create stack label if it doesn't exist
			stack_label = Label.new()
			stack_label.name = "StackLabel"
			slot.add_child(stack_label)
			print("ActiveBuffs: Created new StackLabel")

	if stack_label and stack_label is Label:
		stack_label.text = str(stacks)
		print("ActiveBuffs: Set stack text to: ", str(stacks))
	else:
		print("ActiveBuffs: Stack label not found or not a Label!")

# Called when the scene becomes active
func _enter_tree():
	print("ActiveBuffs: _enter_tree called")
	if Global and Global.has_signal("buff_stacks_changed"):
		print("ActiveBuffs: Connecting to buff_stacks_changed signal")
		Global.buff_stacks_changed.connect(_on_globals_buff_stacks_changed)

func _exit_tree():
	if Global and Global.has_signal("buff_stacks_changed"):
		Global.buff_stacks_changed.disconnect(_on_globals_buff_stacks_changed)

func _on_globals_buff_stacks_changed():
	"""Called when buff stacks change in global"""
	print("ActiveBuffs: Global buff stacks changed - refreshing visibility")
	update_buff_visibility()

# Manual refresh method (can be called externally)
func refresh():
	"""Manually refresh the buff display"""
	print("ActiveBuffs: Manual refresh called")
	update_buff_visibility()
