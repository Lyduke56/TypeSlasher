extends Control

# Manager for existing buff slots - controls visibility of individual BuffSlot instances in active_buffs.tscn
var buff_slot_5: Control  # Rightmost slot
var buff_slot_4: Control
var buff_slot_3: Control
var buff_slot_2: Control
var buff_slot: Control    # Leftmost slot (BuffSlot)

func _ready():
	await get_tree().process_frame
	setup_buff_slot_references()
	update_buff_visibility()

func setup_buff_slot_references():
	"""Get references to existing BuffSlot instances in active_buffs.tscn"""
	# Pattern: BuffSlot5, BuffSlot4, BuffSlot3, BuffSlot2, BuffSlot
	buff_slot_5 = get_node_or_null("../NinePatchRect/GridContainer/BuffSlot5")
	buff_slot_4 = get_node_or_null("../NinePatchRect/GridContainer/BuffSlot4")
	buff_slot_3 = get_node_or_null("../NinePatchRect/GridContainer/BuffSlot3")
	buff_slot_2 = get_node_or_null("../NinePatchRect/GridContainer/BuffSlot2")
	buff_slot = get_node_or_null("../NinePatchRect/GridContainer/BuffSlot")

func update_buff_visibility():
	"""Update visibility of each buff slot based on active buffs from global.gd"""

	# Get active buffs from global
	var active_buffs = get_active_buffs()

	# Assign buffs to slots in reverse order (right to left)
	# BuffSlot5 gets first active buff (rightmost)
	# BuffSlot gets fifth active buff (leftmost)
	var slots = [buff_slot_5, buff_slot_4, buff_slot_3, buff_slot_2, buff_slot]

	for i in range(min(active_buffs.size(), slots.size())):
		var slot = slots[i]
		var buff_info = active_buffs[i]
		if slot:
			slot.visible = true
			update_buff_slot_content(slot, buff_info.stacks, buff_info.icon)

	# Hide remaining slots
	for i in range(active_buffs.size(), slots.size()):
		var slot = slots[i]
		if slot:
			slot.visible = false

	# Hide entire container if no buffs are visible
	var any_buff_visible = false
	for slot in slots:
		if slot and slot.visible:
			any_buff_visible = true
			break

	visible = any_buff_visible

func get_active_buffs() -> Array:
	"""Get list of active buffs for slots from global.gd"""
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

	# Update icon in ActiveBuffSlot - look for TextureRect or Control with icon
	var icon_node = slot.get_node_or_null("TextureRect")
	if not icon_node:
		icon_node = slot

	if icon_node and icon_node is TextureRect:
		icon_node.texture = icon
	elif icon_node and icon_node.has_method("set_icon"):  # If it's a custom buff slot with icon method
		icon_node.set_icon(icon)

	# Update stack count - look for Label or custom stack counter
	var stack_label = slot.get_node_or_null("StackLabel")
	if not stack_label:
		stack_label = slot.get_node_or_null("Stack Counter")

	if stack_label and stack_label is Label:
		stack_label.text = str(stacks)

# Called when the scene becomes active
func _enter_tree():
	# Connect to global buff stack changes if signal exists
	if Global.has_signal("buff_stacks_changed"):
		Global.buff_stacks_changed.connect(_on_globals_buff_stacks_changed)

func _exit_tree():
	# Disconnect from global signals when scene is removed
	if Global.has_signal("buff_stacks_changed"):
		Global.buff_stacks_changed.disconnect(_on_globals_buff_stacks_changed)

func _on_globals_buff_stacks_changed():
	"""Called when buff stacks change in global"""
	update_buff_visibility()

# Manual refresh method (can be called externally)
func refresh():
	"""Manually refresh the buff display"""
	update_buff_visibility()
