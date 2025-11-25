extends "res://Scripts/enemy_base.gd"

@export var blue: Color = Color("#4682b4")
@export var green: Color = Color("#639765")
@export var red: Color = Color("#a65455")

@export var speed: float = 67.0  # Movement speed towards target
@export var health: int = 2  # Enemy health, requires block + 2 damage hits to defeat
@export var word_category: String = "medium"  # Category for enemy words
@onready var anim = $AnimatedSprite2D
@onready var word: RichTextLabel = $Word
@onready var prompt = $Word
@onready var prompt_text = prompt.text
@onready var area: Area2D = $Area2D
@onready var heart_container = $"Node2D/HeartContainer"
@onready var sfx_damaged: AudioStreamPlayer2D = $sfx_damaged
@onready var sfx_death: AudioStreamPlayer2D = $sfx_death
@onready var sfx_attack: AudioStreamPlayer2D = $sfx_attack
