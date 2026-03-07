extends Node2D

## Emitted when the player walks through an exit.  The direction string
## matches a key in LEVELS[level_name]["connections"][room_name] in main.gd.
signal exit_triggered(direction: String)
signal locked_exit_attempted(direction: String, required_key: String)

const _NPCS_NODE: String = "NPCs"
const _ITEMS_NODE: String = "Items"
const _SWITCHES_NODE: String = "Switches"
const _DOORS_NODE: String = "Doors"
const _EXIT_NODE_NAMES: Dictionary = {
	"east": "ExitEast",
	"west": "ExitWest",
	"north": "ExitNorth",
	"south": "ExitSouth",
}

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
		var exit_node: Area2D = _get_exit_node(dir)
		if exit_node != null:
			exit_node.body_entered.connect(_on_exit_body_entered.bind(dir))
	# Connect switches and initialise locked exits from their starting state.
	for sw in get_switches():
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


func get_npcs() -> Array[Node]:
	var npcs_node: Node = get_node_or_null(_NPCS_NODE)
	return npcs_node.get_children() if npcs_node != null else []


func get_items() -> Array[Node]:
	var items_node: Node = get_node_or_null(_ITEMS_NODE)
	return items_node.get_children() if items_node != null else []


func get_switches() -> Array[Node]:
	var switches_node: Node = get_node_or_null(_SWITCHES_NODE)
	return switches_node.get_children() if switches_node != null else []


func get_first_npc_path() -> String:
	var npcs: Array[Node] = get_npcs()
	if npcs.is_empty():
		return ""
	return "%s/%s" % [_NPCS_NODE, npcs[0].name]


func _get_exit_node(direction: String) -> Area2D:
	var node_name: String = _EXIT_NODE_NAMES.get(direction, "")
	if node_name == "":
		return null
	return get_node_or_null(node_name) as Area2D


func _on_exit_body_entered(body: Node, direction: String) -> void:
	if body.is_in_group("player"):
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
	var doors: Node = get_node_or_null(_DOORS_NODE)
	var door: Node = null
	if doors != null:
		door = doors.get_node_or_null("Door_" + switch_id)
	if door != null:
		door.visible = not is_on
		var col := door.get_node_or_null("CollisionShape2D")
		if col:
			col.set_deferred("disabled", is_on)
	# Logical lock: find the switch and update its associated exit.
	for sw in get_switches():
		if sw.id == switch_id and sw.locked_exit != "":
			_locked_exits[sw.locked_exit] = not is_on


## Returns the world-space Rect2 that this room occupies.
## The camera clamps to this rect so the viewport never shows outside the room.
func get_room_rect() -> Rect2:
	return Rect2(global_position, room_size)
