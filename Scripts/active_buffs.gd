extends Control

# --- Drag and drop your .tres files here in the Inspector ---
@export var shield_data: BuffData
@export var sword_data: BuffData
@export var freeze_data: BuffData
@export var health_data: BuffData

# --- References ---
@onready var buff_container = $NinePatchRect/BuffContainer

func _ready():
	# Wait for Global to be ready, just in case





	await get_tree().process_frame

	if Global:
		# Connect to your existing signal
		Global.buff_stacks_changed.connect(update_active_buffs)

	# Initial draw
	update_active_buffs()

func update_active_buffs():
	if not buff_container:
		return

	# 1. Get all slots and hide them initially
	var slots = buff_container.get_children()
	for slot in slots:
		slot.visible = false

	# 2. Reverse the array so we fill from Right-to-Left (preserving your original style)
	slots.reverse()

	# 3. Create a list of what NEEDS to be shown based on Global
	# We store [BuffData, Amount] pairs
	var buffs_to_show: Array = []

	# Logic adapted from your original script:

	# Health (Only if > 3)
	var health_stacks = max(0, Global.player_max_health - 3)
	if health_stacks > 0:
		buffs_to_show.append([health_data, health_stacks])

	# Shield
	if Global.shield_buff_stacks > 0:
		buffs_to_show.append([shield_data, Global.shield_buff_stacks])

	# Sword
	if Global.sword_buff_stacks > 0:
		buffs_to_show.append([sword_data, Global.sword_buff_stacks])

	# Freeze
	if Global.freeze_buff_stacks > 0:
		buffs_to_show.append([freeze_data, Global.freeze_buff_stacks])

	# 4. Assign data to slots
	# We loop through the buffs we need to show and assign them to available slots
	for i in range(min(buffs_to_show.size(), slots.size())):
		var slot = slots[i]
		var data = buffs_to_show[i][0] # The .tres resource
		var amount = buffs_to_show[i][1] # The stack count

		# Call the function on the SLOT script to handle the visuals
		slot.setup_slot(data, amount)

	# 5. Visibility check for the whole container
	visible = buffs_to_show.size() > 0
