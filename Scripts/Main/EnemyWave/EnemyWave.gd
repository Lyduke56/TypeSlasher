class_name EnemyWave
extends Resource

@export var enemy_scene: PackedScene
@export var count: int = 1
@export var spawn_delay: float = 1.5
@export var wave_delay: float = 0.0  # Delay before starting this wave after previous wave completes
