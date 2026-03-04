extends Node2D

# Maps room names to their preloaded scenes.
const ROOMS: Dictionary = {
	"room_a": preload("res://scenes/room_a.tscn"),
	"room_b": preload("res://scenes/room_b.tscn"),
}

# For each room, defines which direction leads to which room and where the
# player appears on arrival (entry position in the destination room).
const ROOM_CONNECTIONS: Dictionary = {
	"room_a": {
		"east": {"room": "room_b", "entry": Vector2(60.0, 240.0)},
	},
	"room_b": {
		"west": {"room": "room_a", "entry": Vector2(580.0, 240.0)},
	},
}

var current_room_name: String = ""
# Untyped to allow calling room.gd methods (get_nearby_npc, exit_triggered).
var current_room = null

@onready var room_holder: Node2D = $RoomHolder
# Untyped to allow accessing player.gd custom signals and properties.
@onready var player = $Player
# Untyped to allow calling dialog_box.gd methods (is_active, start_dialog).
@onready var dialog_box = $HUD/DialogBox
@onready var hp_label: Label = $HUD/HPLabel


func _ready() -> void:
	player.add_to_group("player")
	player.hp_changed.connect(_update_hp_display)
	_load_room("room_a", Vector2(100.0, 240.0))


func _load_room(room_name: String, player_pos: Vector2) -> void:
	if current_room:
		current_room.queue_free()
		await get_tree().process_frame

	current_room_name = room_name
	current_room = ROOMS[room_name].instantiate()
	room_holder.add_child(current_room)
	current_room.exit_triggered.connect(_on_exit_triggered)

	# Give NPCs a reference to the player for hostile chase behaviour.
	# Connect friendly NPC interaction signals.
	if current_room.has_node("NPCs"):
		for npc in current_room.get_node("NPCs").get_children():
			if npc.has_method("set_player_reference"):
				npc.set_player_reference(player)
			if not npc.is_hostile:
				npc.interaction_requested.connect(_on_npc_interaction_requested.bind(npc))

	player.global_position = player_pos
	_update_hp_display(player.hp)


func _on_exit_triggered(direction: String) -> void:
	if current_room_name not in ROOM_CONNECTIONS:
		return
	var connections: Dictionary = ROOM_CONNECTIONS[current_room_name]
	if direction not in connections:
		return
	var next: Dictionary = connections[direction]
	_load_room(next["room"], next["entry"])


func _on_npc_interaction_requested(npc: Node) -> void:
	if dialog_box.is_active():
		return
	dialog_box.start_dialog(npc.dialog_lines)


func _update_hp_display(new_hp: int) -> void:
	hp_label.text = "HP: " + str(new_hp)
