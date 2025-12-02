extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var freeze_vines: AnimatedSprite2D = $FreezeVines

var original_sprite_frames: SpriteFrames
var is_frozen: bool = false
var is_dying: bool = false
var current_health: int = 1

func _ready() -> void:
	call_deferred("_store_original_frames")

func _store_original_frames():
	if anim:
		original_sprite_frames = anim.sprite_frames
	if freeze_vines:
		freeze_vines.visible = false

func take_damage(amount: int = 1):
	current_health -= amount
	if current_health <= 0:
		# 1. MARK AS DYING
		is_dying = true

		# 2. FORCE UNFREEZE (Critical Fix)
		# If the enemy was frozen when it died, we must break that state immediately
		is_frozen = false
		if freeze_vines:
			freeze_vines.visible = false
		else:
			anim.modulate = Color.WHITE
			if anim.is_paused():
				anim.play()

		# 3. STOP PHYSICS
		set_physics_process(false)

		# 4. TRIGGER DEATH ANIMATION
		# This ensures the child script (Skeleton/Slime) plays "death"
		# instead of getting stuck in "idle" or "freeze"
		if has_method("play_death_animation"):
			call("play_death_animation")
		else:
			queue_free()

func _physics_process(delta: float) -> void:
	if is_dying or is_frozen:
		return

func pause_enemy(duration: float) -> void:
	# 5. REJECT FREEZE COMMAND (Critical Fix)
	# If Global tries to freeze us while we are dying, IGNORE IT.
	if is_dying or not anim:
		return

	# If we are already frozen, just reset the timer (optional), but for now we ignore
	if is_frozen:
		return

	is_frozen = true

	var current_animation = anim.animation
	var current_flip = anim.flip_h
	var was_playing = anim.is_playing()

	if freeze_vines:
		freeze_vines.visible = true
		freeze_vines.play("freeze")
	else:
		# Use modulate effect instead of changing sprite
		anim.modulate = Color.CYAN
		anim.pause()
		# Keep word visible
		if has_node("Word"):
			get_node("Word").modulate = Color.WHITE

	# Stop hacking if applicable
	if has_method("get") and get("hack_timer") != null:
		var ht = get("hack_timer")
		if ht is Timer and ht.is_inside_tree():
			ht.stop()

	# Wait for the freeze duration
	await get_tree().create_timer(duration).timeout

	# 6. CHECK DEATH AGAIN
	# If we died while waiting for the timer, DO NOT switch animation back
	if is_dying:
		return

	if freeze_vines:
		freeze_vines.visible = false
	else:
		# Restore modulate and animation
		anim.modulate = Color.WHITE
		if was_playing:
			anim.play(current_animation)
		anim.flip_h = current_flip
		# Restore word modulate to match current state
		if has_node("Word"):
			get_node("Word").modulate = self.modulate

	# Resume hacking if applicable
	if has_method("get") and get("hack_timer") != null and has_method("get") and get("has_reached_target") == true:
		var ht = get("hack_timer")
		if ht is Timer and ht.is_inside_tree():
			ht.start()

	is_frozen = false
