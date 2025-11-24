extends HSlider

@export var audio_bus_name: String

var audio_bus_id

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	if audio_bus_id == -1:
		push_error("Audio bus '" + audio_bus_name + "' not found!")


func _on_value_changed(value: float) -> void:
	var db = linear_to_db(value)
	AudioServer.set_bus_volume_db(audio_bus_id, db)
