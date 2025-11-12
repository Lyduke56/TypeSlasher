extends ParallaxLayer

@export var SPEED: float = -5

func _process(delta) -> void:
	self.motion_offset.x += SPEED
