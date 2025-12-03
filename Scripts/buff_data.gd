extends Resource
class_name BuffData

@export var buff_name: String = "Buff Name"
@export_multiline var description: String = "Buff Description"
@export var icon: Texture2D
@export var type: BuffType

enum BuffType {
	SHIELD,
	SWORD,
	FREEZE,
	HEALTH
}
