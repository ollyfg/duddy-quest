extends Node2D

## Emitted when the player walks through an exit.  The direction string
## matches a key in LEVELS[level_name]["connections"][room_name] in main.gd.
signal exit_triggered(direction: String)

const INTERACT_RANGE: float = 60.0

## Size of this room in pixels.  Used by the camera to clamp the viewport.
@export var room_size: Vector2 = Vector2(640.0, 480.0)

## Maps exit direction → true when that exit is currently locked by a switch.
var _locked_exits: Dictionary = {}


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


func _on_exit_body_entered(body: Node, direction: String) -> void:
	if body.is_in_group("player"):
		if _locked_exits.get(direction, false):
			return  # Exit is locked by a switch.
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
