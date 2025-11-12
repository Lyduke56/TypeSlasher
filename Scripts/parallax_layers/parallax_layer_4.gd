extends ParallaxLayer

@export var SPEED: float = -15

func _process(delta) -> void:
	self.motion_offset.x += SPEED
