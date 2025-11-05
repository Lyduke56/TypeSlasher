extends Control

@onready var health_buff = $GridContainer/HealthBuff
@onready var shield_buff = $GridContainer/ShieldBuff
@onready var sword_buff = $GridContainer/SwordBuff

func _ready():
	update_buff_display()

func update_buff_display():
	# Health buff - show if max health > 3 (since 3 is default)
	var health_stacks = max(0, Global.player_max_health - 3)
	health_buff.visible = health_stacks > 0
	if health_buff.visible:
		health_buff.get_node("StackLabel").text = str(health_stacks)

	# Shield buff
	shield_buff.visible = Global.shield_buff_stacks > 0
	if shield_buff.visible:
		shield_buff.get_node("StackLabel").text = str(Global.shield_buff_stacks)

	# Sword buff
	sword_buff.visible = Global.sword_buff_stacks > 0
	if sword_buff.visible:
		sword_buff.get_node("StackLabel").text = str(Global.sword_buff_stacks)
