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


func _on_exit_body_entered(body: Node, direction: String) -> void:
	if body.is_in_group("player"):
		exit_triggered.emit(direction)


## Returns the nearest friendly NPC within interaction range, or null.
func get_nearby_npc(pos: Vector2) -> Node:
	if not has_node("NPCs"):
		return null
	for npc in get_node("NPCs").get_children():
		if not npc.is_hostile and npc.global_position.distance_to(pos) <= INTERACT_RANGE:
			return npc
	return null
