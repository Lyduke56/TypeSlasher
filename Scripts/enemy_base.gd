extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var freeze_vines: AnimatedSprite2D = $FreezeVines  # New freeze overlay

var original_sprite_frames: SpriteFrames  # Store original frames
var is_frozen: bool = false

func _ready() -> void:
	# Store original sprite_frames in ready, after [auto]
	call_deferred("_store_original_frames")

func _store_original_frames():
	if anim:
		original_sprite_frames = anim.sprite_frames
	# Hide freeze vines by default
	if freeze_vines:
		freeze_vines.visible = false

func _physics_process(delta: float) -> void:
	if is_frozen:
		return  # Don't move during freeze

func pause_enemy(duration: float) -> void:
	if is_frozen or not anim:
		return

	is_frozen = true

	# Store current animation state
	var current_animation = anim.animation
	var current_flip = anim.flip_h

	# Show freeze vines on top of main animation (no sprite swap)
	if freeze_vines:
		freeze_vines.visible = true
		freeze_vines.play("freeze")
		# Optionally switch to idle animation
		# anim.play("idle ")  # Leave for override
	else:
		# Fallback to sprite_frames swap
		anim.sprite_frames = preload("res://Scenes/freeze.tres")
		anim.play("freeze")

	# Wait for duration
	await get_tree().create_timer(duration).timeout

	# Hide freeze vines or restore sprite_frames
	if freeze_vines:
		freeze_vines.visible = false
	else:
		# Restore original sprite_frames
		if original_sprite_frames:
			anim.sprite_frames = original_sprite_frames
			anim.play(current_animation)
			anim.flip_h = current_flip

	is_frozen = false
