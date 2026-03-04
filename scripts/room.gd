extends Node2D

## Emitted when the player walks through an exit.  The direction string
## matches the key used in the ROOM_CONNECTIONS map in main.gd.
signal exit_triggered(direction: String)

const INTERACT_RANGE: float = 60.0


func _ready() -> void:
	# Connect exit Area2D signals that exist in this room instance.
	for dir in ["east", "west", "north", "south"]:
		var node_name: String = "Exit" + dir.capitalize()
		if has_node(node_name):
			get_node(node_name).body_entered.connect(
				_on_exit_body_entered.bind(dir)
			)
	# Connect any switches so they can affect doors in this room.
	if has_node("Switches"):
		for sw in get_node("Switches").get_children():
			if sw.has_signal("toggled"):
				sw.toggled.connect(_on_switch_toggled)


func _on_exit_body_entered(body: Node, direction: String) -> void:
	if body.is_in_group("player"):
		exit_triggered.emit(direction)


## Called when a switch is toggled.  Finds a matching door under the Doors
## node (named "Door_<switch_id>") and shows/hides it.
func _on_switch_toggled(switch_id: String, is_on: bool) -> void:
	var door_path := "Doors/Door_" + switch_id
	if has_node(door_path):
		var door := get_node(door_path)
		door.visible = not is_on
		var col := door.get_node_or_null("CollisionShape2D")
		if col:
			col.set_deferred("disabled", is_on)


## Returns the nearest friendly NPC within interaction range, or null.
func get_nearby_npc(pos: Vector2) -> Node:
	if not has_node("NPCs"):
		return null
	for npc in get_node("NPCs").get_children():
		if not npc.is_hostile and npc.global_position.distance_to(pos) <= INTERACT_RANGE:
			return npc
	return null
