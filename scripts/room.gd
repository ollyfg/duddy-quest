extends Node2D

## Emitted when the player walks through an exit.  The direction string
## matches a key in LEVELS[level_name]["connections"][room_name] in main.gd.
signal exit_triggered(direction: String)
signal locked_exit_attempted(direction: String, required_key: String)

const INTERACT_RANGE: float = 60.0

## Size of this room in pixels.  Used by the camera to clamp the viewport.
@export var room_size: Vector2 = Vector2(640.0, 480.0)

## Optional key item IDs required to use each exit direction.
## Set these in the scene to require the player to collect a key before exiting.
@export var key_east: String = ""
@export var key_west: String = ""
@export var key_north: String = ""
@export var key_south: String = ""

## Maps exit direction → true when that exit is currently locked by a switch.
var _locked_exits: Dictionary = {}
## Maps exit direction → key_id required to use that exit.
var _exit_keys: Dictionary = {}

func set_exit_key(direction: String, key_id: String) -> void:
	_exit_keys[direction] = key_id


func _ready() -> void:
	# Connect exit Area2D signals that exist in this room instance.
	for dir in ["east", "west", "north", "south"]:
		var node_name: String = "Exit" + dir.capitalize()
		if has_node(node_name):
			get_node(node_name).body_entered.connect(
				_on_exit_body_entered.bind(dir)
			)
	# Connect switches and initialise locked exits from their starting state.
	if has_node("Switches"):
		for sw in get_node("Switches").get_children():
			if sw.has_signal("toggled"):
				sw.toggled.connect(_on_switch_toggled)
				# A switch with locked_exit that starts OFF locks that exit.
				if sw.locked_exit != "":
					_locked_exits[sw.locked_exit] = not sw.starts_on
	# Initialise any exit key requirements set via scene exports.
	if key_east != "": _exit_keys["east"] = key_east
	if key_west != "": _exit_keys["west"] = key_west
	if key_north != "": _exit_keys["north"] = key_north
	if key_south != "": _exit_keys["south"] = key_south


func _on_exit_body_entered(body: Node, direction: String) -> void:
	if body.is_in_group("player"):
		print("DEBUG room exit body_entered: dir=%s body_pos=%s" % [direction, body.global_position])
		if _locked_exits.get(direction, false):
			return  # Exit is locked by a switch.
		var req_key: String = _exit_keys.get(direction, "")
		if req_key != "":
			if not body.has_key(req_key):
				locked_exit_attempted.emit(direction, req_key)
				return
			else:
				body.remove_key(req_key)
		exit_triggered.emit(direction)


## Called when a switch is toggled.  Updates the visual door and locked exit.
func _on_switch_toggled(switch_id: String, is_on: bool) -> void:
	# Visual door: show when switch is off (door closed), hide when on (open).
	var door_path := "Doors/Door_" + switch_id
	if has_node(door_path):
		var door := get_node(door_path)
		door.visible = not is_on
		var col := door.get_node_or_null("CollisionShape2D")
		if col:
			col.set_deferred("disabled", is_on)
	# Logical lock: find the switch and update its associated exit.
	if has_node("Switches"):
		for sw in get_node("Switches").get_children():
			if sw.id == switch_id and sw.locked_exit != "":
				_locked_exits[sw.locked_exit] = not is_on


## Returns the world-space Rect2 that this room occupies.
## The camera clamps to this rect so the viewport never shows outside the room.
func get_room_rect() -> Rect2:
	return Rect2(global_position, room_size)


## Returns the nearest friendly NPC within interaction range, or null.
func get_nearby_npc(pos: Vector2) -> Node:
	if not has_node("NPCs"):
		return null
	for npc in get_node("NPCs").get_children():
		if not npc.is_hostile and npc.global_position.distance_to(pos) <= INTERACT_RANGE:
			return npc
	return null
