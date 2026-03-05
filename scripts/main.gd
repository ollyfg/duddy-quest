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
# Persists room state (surviving NPC positions/HP) across room transitions.
var _room_states: Dictionary = {}

@onready var room_holder: Node2D = $RoomHolder
# Untyped to allow accessing player.gd custom signals and properties.
@onready var player = $Player
# Untyped to allow calling dialog_box.gd methods (is_active, start_dialog).
@onready var dialog_box = $HUD/DialogBox
@onready var hp_label: Label = $HUD/HPLabel
@onready var mobile_controls = $MobileControls


func _ready() -> void:
	player.add_to_group("player")
	player.hp_changed.connect(_update_hp_display)
	player.wand_acquired.connect(_on_wand_acquired)
	player.died.connect(_on_player_died)
	dialog_box.dialog_ended.connect(_on_dialog_ended)

	# Allow launching into a specific level via --level <name> CLI argument;
	# otherwise use the level chosen on the level-select screen.
	var args := OS.get_cmdline_user_args()
	# Fall back to "training" if the stored level is missing from LEVELS.
	var level_name: String = GameState.selected_level if GameState.selected_level in LEVELS else "training"
	var idx := args.find("--level")
	if idx >= 0:
		if idx + 1 < args.size():
			var requested: String = args[idx + 1]
			if requested in LEVELS:
				level_name = requested
			else:
				push_warning("Unknown level '%s', falling back to '%s'." % [requested, level_name])
		else:
			push_warning("--level flag provided without a value, using '%s'." % level_name)

	_load_level(level_name)


func _load_level(level_name: String) -> void:
	current_level_name = level_name
	_room_states.clear()
	var level: Dictionary = LEVELS[level_name]
	if level_name == "training":
		play_cutscene([
			{"image": null, "text": "D. DURSLEY (THE LARGER ONE)...\nYour journey begins.", "background_color": Color(0.05, 0.05, 0.15)},
			{"image": null, "text": "Find the exits and fight your way through the training rooms.", "background_color": Color(0.05, 0.05, 0.15)},
		], func(): _load_room(level["start_room"], level["start_pos"]))
	else:
		_load_room(level["start_room"], level["start_pos"])


func _load_room(room_name: String, player_pos: Vector2) -> void:
	if current_room:
		_save_room_state()
		current_room.queue_free()
		await get_tree().process_frame

	current_room_name = room_name
	var level_rooms: Dictionary = LEVELS[current_level_name]["rooms"]
	current_room = level_rooms[room_name].instantiate()
	room_holder.add_child(current_room)
	current_room.exit_triggered.connect(_on_exit_triggered)

	# Restore saved state (remove dead NPCs, reapply positions/HP) before
	# connecting any signals so we never wire up nodes about to be freed.
	_restore_room_state(room_name)

	# Give NPCs a reference to the player for hostile chase behaviour.
	# Connect friendly NPC interaction signals.
	if current_room.has_node("NPCs"):
		for npc in current_room.get_node("NPCs").get_children():
			if npc.is_queued_for_deletion():
				continue
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


## Snapshot the current room's NPC, item, and switch states before transitioning away.
func _save_room_state() -> void:
	if current_room == null or current_room_name == "":
		return
	var npc_states: Dictionary = {}
	if current_room.has_node("NPCs"):
		for npc in current_room.get_node("NPCs").get_children():
			npc_states[npc.name] = {
				"position": npc.global_position,
				"hp": npc.hp,
			}
	# Items: record the names of items that are still present (picked-up items
	# will have already been queue_free()'d and won't appear here).
	var item_names: Array[String] = []
	if current_room.has_node("Items"):
		for item in current_room.get_node("Items").get_children():
			item_names.append(item.name)
	# Switches: record each switch's current on/off state.
	var switch_states: Dictionary = {}
	if current_room.has_node("Switches"):
		for sw in current_room.get_node("Switches").get_children():
			switch_states[sw.name] = sw.is_on
	_room_states[current_room_name] = {
		"npcs": npc_states,
		"items": item_names,
		"switches": switch_states,
	}


## Re-apply a previously saved snapshot to the newly instantiated room.
## NPCs absent from the snapshot (killed) and items absent (picked up) are
## freed immediately.  Switches are toggled to their saved state if it differs
## from their starting state, which also updates doors and locked exits via the
## existing toggled signal.
func _restore_room_state(room_name: String) -> void:
	if room_name not in _room_states:
		return
	var state: Dictionary = _room_states[room_name]
	# Restore NPCs.
	if current_room.has_node("NPCs") and "npcs" in state:
		var npc_states: Dictionary = state["npcs"]
		for npc in current_room.get_node("NPCs").get_children():
			if npc.name not in npc_states:
				npc.queue_free()
			else:
				var npc_data: Dictionary = npc_states[npc.name]
				npc.global_position = npc_data["position"]
				npc.hp = npc_data["hp"]
	# Restore items: remove any item that was already collected.
	if current_room.has_node("Items") and "items" in state:
		var present_items: Array[String] = state["items"]
		for item in current_room.get_node("Items").get_children():
			if item.name not in present_items:
				item.queue_free()
	# Restore switches: call on_hit() for any switch whose saved state differs
	# from its starting state so the visual, door, and locked-exit are updated.
	# on_hit() is called at most once per switch (the condition guarantees this),
	# toggling from starts_on to the saved state in a single authorized step.
	if current_room.has_node("Switches") and "switches" in state:
		var switch_states: Dictionary = state["switches"]
		for sw in current_room.get_node("Switches").get_children():
			if sw.name in switch_states and sw.is_on != switch_states[sw.name]:
				sw.on_hit()


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
	var dots := ""
	for i: int in range(player.MAX_HP):
		dots += "●" if i < new_hp else "○"
	hp_label.text = dots


func _on_player_died() -> void:
	# Show a "GAME OVER" overlay then return to the level-select screen.
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var label := Label.new()
	label.text = "GAME OVER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font_size_prop := &"theme_override_font_sizes/font_size"
	label.set(font_size_prop, 32)
	overlay.add_child(label)

	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_wand_acquired() -> void:
	_update_wand_display()


func _update_wand_display() -> void:
	mobile_controls.set_ranged_visible(player.has_wand)


func play_cutscene(slides: Array, on_finish: Callable) -> void:
	var cutscene_scene: PackedScene = load("res://scenes/cutscene.tscn")
	var cutscene: Node = cutscene_scene.instantiate()
	add_child(cutscene)
	cutscene.cutscene_finished.connect(func():
		on_finish.call()
		cutscene.queue_free()
	)
	cutscene.play(slides)
