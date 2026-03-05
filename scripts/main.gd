extends Node2D

# Each level groups its rooms, connections, starting room and starting position.
const LEVELS: Dictionary = {
	"training": {
		"start_room": "room_a",
		"start_pos": Vector2(96.0, 240.0),
		"rooms": {
			"room_a": preload("res://scenes/room_a.tscn"),
			"room_b": preload("res://scenes/room_b.tscn"),
			"room_c": preload("res://scenes/room_c.tscn"),
			"room_d": preload("res://scenes/room_d.tscn"),
		},
		"connections": {
			"room_a": {
				"east": {"room": "room_b", "entry": Vector2(64.0, 240.0)},
			},
			"room_b": {
				"west": {"room": "room_a", "entry": Vector2(576.0, 240.0)},
				"east": {"room": "room_c", "entry": Vector2(64.0, 240.0)},
			},
			"room_c": {
				"west": {"room": "room_b", "entry": Vector2(576.0, 240.0)},
				"east": {"room": "room_d", "entry": Vector2(64.0, 240.0)},
			},
			"room_d": {
				"west": {"room": "room_c", "entry": Vector2(576.0, 240.0)},
			},
		},
	},
}

var current_level_name: String = ""
var current_room_name: String = ""
# Untyped to allow calling room.gd methods (get_nearby_npc, exit_triggered).
var current_room = null

@onready var room_holder: Node2D = $RoomHolder
# Untyped to allow accessing player.gd custom signals and properties.
@onready var player = $Player
# Untyped to allow calling dialog_box.gd methods (is_active, start_dialog).
@onready var dialog_box = $HUD/DialogBox
@onready var hp_label: Label = $HUD/HPLabel
@onready var wand_label: Label = $HUD/WandLabel


func _ready() -> void:
	player.add_to_group("player")
	player.hp_changed.connect(_update_hp_display)
	player.wand_acquired.connect(_on_wand_acquired)
	dialog_box.dialog_ended.connect(_on_dialog_ended)

	# Allow launching into a specific level via --level <name> CLI argument.
	var args := OS.get_cmdline_user_args()
	var level_name := "training"
	var idx := args.find("--level")
	if idx >= 0:
		if idx + 1 < args.size():
			var requested: String = args[idx + 1]
			if requested in LEVELS:
				level_name = requested
			else:
				push_warning("Unknown level '%s', falling back to 'training'." % requested)
		else:
			push_warning("--level flag provided without a value, using 'training'.")

	_load_level(level_name)


func _load_level(level_name: String) -> void:
	current_level_name = level_name
	var level: Dictionary = LEVELS[level_name]
	_load_room(level["start_room"], level["start_pos"])


func _load_room(room_name: String, player_pos: Vector2) -> void:
	if current_room:
		current_room.queue_free()
		await get_tree().process_frame

	current_room_name = room_name
	var level_rooms: Dictionary = LEVELS[current_level_name]["rooms"]
	current_room = level_rooms[room_name].instantiate()
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
	# Reset any in-progress grid step so stale movement from the old room
	# does not carry over and lock the player's controls in the new room.
	player.cancel_movement()
	player.set_camera_limits(current_room.get_room_rect())
	_update_hp_display(player.hp)
	_update_wand_display()


func _on_exit_triggered(direction: String) -> void:
	if current_room_name not in LEVELS[current_level_name]["connections"]:
		return
	var connections: Dictionary = LEVELS[current_level_name]["connections"][current_room_name]
	if direction not in connections:
		return
	var next: Dictionary = connections[direction]
	_load_room(next["room"], next["entry"])


func _on_npc_interaction_requested(npc: Node) -> void:
	if dialog_box.is_active():
		return
	_set_dialog_active(true)
	dialog_box.start_dialog(npc.dialog_lines)


func _on_dialog_ended() -> void:
	_set_dialog_active(false)


func _set_dialog_active(active: bool) -> void:
	player.is_in_dialog = active
	if current_room and current_room.has_node("NPCs"):
		for npc in current_room.get_node("NPCs").get_children():
			npc.is_paused = active


func _update_hp_display(new_hp: int) -> void:
	hp_label.text = "HP: " + str(new_hp)


func _on_wand_acquired() -> void:
	_update_wand_display()


func _update_wand_display() -> void:
	wand_label.text = "Wand: " + ("YES" if player.has_wand else "NO")
