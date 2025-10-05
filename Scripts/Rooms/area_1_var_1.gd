extends Node2D

@onready var player = $Player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_rooms()
	setup_dungeon_manager()

func setup_rooms():
	# Attach Room.gd script to each room node first
	var room_script = load("res://Scripts/Room.gd")
	$StartingRoom.set_script(room_script)
	$"RoomA - Medium".set_script(room_script)
	$"RoomC - Medium".set_script(room_script)
	$"RoomB - Small".set_script(room_script)
	$PortalRoom.set_script(room_script)

	# Manually set room types since auto-parsing might not fit all names perfectly
	$StartingRoom.room_type = "Medium"
	$"RoomA - Medium".room_type = "Medium"
	$"RoomC - Medium".room_type = "Medium"
	$"RoomB - Small".room_type = "Small"
	$PortalRoom.room_type = "Boss"  # Assuming PortalRoom is the end

	# Set adjacent rooms for navigation
	$StartingRoom.adjacent_rooms["Right"] = $"RoomA - Medium".get_path()
	$StartingRoom.adjacent_rooms["Bottom"] = $"RoomB - Small".get_path()

	$"RoomA - Medium".adjacent_rooms["Left"] = $StartingRoom.get_path()
	$"RoomA - Medium".adjacent_rooms["Bottom"] = $PortalRoom.get_path()

	$"RoomB - Small".adjacent_rooms["Top"] = $PortalRoom.get_path()  # Assuming HallwayTop leads to PortalRoom

	$PortalRoom.adjacent_rooms["Top"] = $"RoomB - Small".get_path()
	$PortalRoom.adjacent_rooms["Left"] = $"RoomA - Medium".get_path()

	# RoomC - Medium has no connections, leave default empty

	# Spawn scenes disabled for now, focus on room transition

func setup_dungeon_manager():
	# Add DungeonManager node
	var dungeon_manager = Node.new()
	dungeon_manager.set_script(load("res://Scripts/DungeonManager.gd"))
	dungeon_manager.name = "DungeonManager"
	add_child(dungeon_manager)

	# Set exported variables
	dungeon_manager.player = player.get_path()
	dungeon_manager.starting_room = $StartingRoom.get_path()

	# Ensure DungeonManager initializes properly by calling its enter_room manually if not done in _ready
	# But since _ready of DungeonManager calls enter_room(starting_room), it should be fine after add_child

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
