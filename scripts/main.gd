extends Node2D

# Each level groups its rooms, connections, starting room and starting position.
const LEVELS: Dictionary = {
	"training": {
		"title": "Training",
		"next_level": "",
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
	"level_1": {
		"title": "A Perfectly Normal Catastrophe",
		"next_level": "",
		"start_room": "l1_bedroom",
		"start_pos": Vector2(80.0, 240.0),
		"rooms": {
			"l1_bedroom": preload("res://scenes/l1_bedroom.tscn"),
			"l1_upper_hall": preload("res://scenes/l1_upper_hall.tscn"),
			"l1_hallway": preload("res://scenes/l1_hallway.tscn"),
			"l1_front_hall": preload("res://scenes/l1_front_hall.tscn"),
			"l1_garden": preload("res://scenes/l1_garden.tscn"),
			"l1_street": preload("res://scenes/l1_street.tscn"),
		},
		"connections": {
			"l1_bedroom": {
				"east": {"room": "l1_upper_hall", "entry": Vector2(64.0, 240.0)},
			},
			"l1_upper_hall": {
				"west": {"room": "l1_bedroom", "entry": Vector2(576.0, 240.0)},
				"east": {"room": "l1_hallway", "entry": Vector2(64.0, 240.0)},
			},
			"l1_hallway": {
				"west": {"room": "l1_upper_hall", "entry": Vector2(576.0, 240.0)},
				"east": {"room": "l1_front_hall", "entry": Vector2(64.0, 240.0)},
			},
			"l1_front_hall": {
				"west": {"room": "l1_hallway", "entry": Vector2(576.0, 240.0)},
				"east": {"room": "l1_garden", "entry": Vector2(64.0, 240.0)},
			},
			"l1_garden": {
				"west": {"room": "l1_front_hall", "entry": Vector2(576.0, 240.0)},
				"east": {"room": "l1_street", "entry": Vector2(64.0, 240.0)},
			},
			"l1_street": {
				"west": {"room": "l1_garden", "entry": Vector2(576.0, 240.0)},
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
@onready var key_label: Label = $HUD/KeyLabel
@onready var rage_bar: ProgressBar = $HUD/RageBar
@onready var mobile_controls = $MobileControls

var _cinematic_player: Node = null
## Set to "go_west" by _on_npc_player_detected; consumed in _on_dialog_ended
## to send the player back to the previous room after the "caught" dialog.
var _post_dialog_action: String = ""
## Tracks the NPC whose dialog is currently active so post-dialog actions
## (giving keys, accepting keys, setting flags) can be applied on close.
var _interacting_npc: Node = null
## Guards against re-entrant _on_exit_triggered calls during the one-frame
## await in _load_room (prevents concurrent room loads via the old room's
## still-connected exit signals).
var _room_loading: bool = false


func _ready() -> void:
	player.add_to_group("player")
	player.hp_changed.connect(_update_hp_display)
	player.wand_acquired.connect(_on_wand_acquired)
	player.died.connect(_on_player_died)
	player.keys_changed.connect(_update_key_display)
	player.rage_changed.connect(_update_rage_bar)
	player.rage_attack.connect(_on_rage_attack)
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
	elif level_name == "level_1":
		play_cutscene([
			{"image": null, "text": "4 PRIVET DRIVE, LITTLE WHINGING\nA perfectly normal Saturday morning.", "background_color": Color(0.12, 0.08, 0.04)},
			{"image": null, "text": "You are DUDLEY DURSLEY.\nYou have just found an unopened Hogwarts letter\nhidden in Aunt Petunia's shoebox.", "background_color": Color(0.12, 0.08, 0.04)},
			{"image": null, "text": "Smeltings stick in hand, you are about to take\nthe most roundabout path to Hogwarts\nin the school's nine-hundred-year history.", "background_color": Color(0.12, 0.08, 0.04)},
		], func(): _load_room(level["start_room"], level["start_pos"]))
	else:
		_load_room(level["start_room"], level["start_pos"])


func _load_room(room_name: String, player_pos: Vector2) -> void:
	_room_loading = true
	if current_room:
		_save_room_state()
		# Disconnect the old room's exit signals first so that any in-flight
		# physics body_entered callbacks queued on the old room's exit Area2D
		# nodes cannot fire _on_exit_triggered in the new room's context.  The
		# nodes are freed on the same frame via queue_free, but Godot may still
		# emit a deferred body_entered before the free completes.
		if current_room.exit_triggered.is_connected(_on_exit_triggered):
			current_room.exit_triggered.disconnect(_on_exit_triggered)
		if current_room.locked_exit_attempted.is_connected(_on_locked_exit_attempted):
			current_room.locked_exit_attempted.disconnect(_on_locked_exit_attempted)
		current_room.queue_free()
		await get_tree().process_frame

	# Teleport the player to the entry position BEFORE adding the new room to
	# the scene so that the physics server records the new position.  The new
	# room's exit Area2D nodes will see the player at the correct entry point
	# when they are first registered, not at any stale position from the
	# previous room.
	player.global_position = player_pos
	player.cancel_movement()
	current_room_name = room_name
	var level_rooms: Dictionary = LEVELS[current_level_name]["rooms"]
	current_room = level_rooms[room_name].instantiate()
	room_holder.add_child(current_room)
	current_room.exit_triggered.connect(_on_exit_triggered)
	current_room.locked_exit_attempted.connect(_on_locked_exit_attempted)

	# Connect level-end triggers.
	for trigger in get_tree().get_nodes_in_group("level_end"):
		if trigger.has_signal("level_end_reached") and not trigger.level_end_reached.is_connected(_on_level_end_reached):
			trigger.level_end_reached.connect(_on_level_end_reached.bind(trigger))

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
			if npc.is_in_group("boss") and npc.has_signal("boss_defeated"):
				npc.boss_defeated.connect(_on_boss_defeated)
				npc.interaction_requested.connect(_on_npc_interaction_requested.bind(npc))
			elif not npc.is_hostile:
				npc.interaction_requested.connect(_on_npc_interaction_requested.bind(npc))
			if npc.detection_dialog != "":
				npc.player_detected.connect(_on_npc_player_detected)
			# Any NPC with cinematic_kick_back set triggers the Petunia
			# kick-back cinematic when it physically contacts the player.
			# We also add a physics collision exception so the NPC's body does
			# not push the player around before the cinematic fires.
			if npc.cinematic_kick_back:
				npc.add_collision_exception_with(player)
				player.add_collision_exception_with(npc)
				npc.player_hit.connect(_on_petunia_hit_player)

	player.set_camera_limits(current_room.get_room_rect())
	_update_hp_display(player.hp)
	_update_wand_display()

	# Connect the bedroom door hint signal (fires first time player bumps door).
	if room_name == "l1_bedroom":
		var door: Node = current_room.get_node_or_null("MagicDoor")
		if door != null and door.has_signal("door_approached"):
			door.door_approached.connect(_on_bedroom_door_approached)

	_room_loading = false

	# Demo cinematic on first entry to room_a.
	if room_name == "room_a" and "room_a" not in _room_states:
		if current_room.has_node("NPCs") and current_room.get_node("NPCs").get_child_count() > 0:
			var npc_path: String = "NPCs/" + current_room.get_node("NPCs").get_child(0).name
			play_cinematic([
				{"type": "dialog", "speaker": npc_path, "lines": ["Welcome to the training area, Dudley!"]},
			], func() -> void: pass)


## Snapshot the current room's NPC, item, and switch states before transitioning away.
func _save_room_state() -> void:
	if current_room == null or current_room_name == "":
		return
	var npc_states: Dictionary = {}
	if current_room.has_node("NPCs"):
		for npc in current_room.get_node("NPCs").get_children():
			# Skip NPCs that have already been removed (e.g. picked-up cats).
			if npc.is_queued_for_deletion():
				continue
			npc_states[npc.name] = {
				"position": npc.global_position,
				"hp": npc.hp,
			}
	# Items: record the names of items that are still present (picked-up items
	# will have already been queue_free()'d and won't appear here).
	var item_names: Array[String] = []
	if current_room.has_node("Items"):
		for item in current_room.get_node("Items").get_children():
			if not item.is_queued_for_deletion():
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
	# Guard against re-entrant calls while a room transition is already in
	# progress (the one-frame await in _load_room leaves the old room's exit
	# signals connected for one frame, which could cause a concurrent load).
	if _room_loading:
		return
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
	_interacting_npc = npc
	_set_dialog_active(true)
	dialog_box.start_dialog(_pick_npc_dialog(npc))


## Choose the correct dialog lines for an NPC, respecting flag gates and
## key-requirement states.
func _pick_npc_dialog(npc: Node) -> Array:
	# Key-accepting NPC and the player already carries the required key.
	if npc.requires_key_id != "" and player.has_key(npc.requires_key_id):
		return npc.key_accept_dialog if not npc.key_accept_dialog.is_empty() else npc.dialog_lines

	# Work out whether any flag gate applies to this NPC.
	var gate_flag: String = ""
	if npc.gives_key_id != "":
		gate_flag = npc.gives_key_flag
	if gate_flag == "" and npc.requires_flag != "":
		gate_flag = npc.requires_flag

	if gate_flag != "" and not GameState.has_flag(gate_flag):
		return npc.pre_flag_dialog if not npc.pre_flag_dialog.is_empty() else ["..."]

	return npc.dialog_lines


## Called when a PATROL NPC spots the player for the first time this room visit.
## Shows the NPC's detection line then sends the player back the way they came.
func _on_npc_player_detected(dialog: String) -> void:
	if dialog_box.is_active() or _post_dialog_action != "":
		return
	_post_dialog_action = "go_west"
	_set_dialog_active(true)
	dialog_box.start_dialog([dialog])


func _on_bedroom_door_approached() -> void:
	if GameState.l1_bedroom_door_hint_shown or dialog_box.is_active():
		return
	GameState.l1_bedroom_door_hint_shown = true
	_set_dialog_active(true)
	dialog_box.start_dialog([
		"You try to open the door but it's locked.",
		"Maybe if you whack it enough...",
	])


## Called when Petunia's HitArea physically contacts the player.
## Shows her catch line then plays a cinematic marching the player back to the
## hallway's west exit before loading the previous room.
func _on_petunia_hit_player() -> void:
	if _room_loading or player.cinematic_mode or dialog_box.is_active() or _post_dialog_action != "":
		return
	_post_dialog_action = "petunia_kick"
	_set_dialog_active(true)
	dialog_box.start_dialog(["Back to your room, DUDDIKINS!"])


func _on_dialog_ended() -> void:
	_set_dialog_active(false)
	var action: String = _post_dialog_action
	_post_dialog_action = ""

	# A "go_west" post-dialog action takes priority (Petunia sending player back).
	if action == "go_west":
		_interacting_npc = null
		_on_exit_triggered("west")
		return

	# Petunia catches the player: cinematic marching them back to the bedroom door.
	if action == "petunia_kick":
		_interacting_npc = null
		# Return Petunia (and any other cinematic_kick_back NPC) to her patrol
		# route immediately so she doesn't continue chasing during the escort.
		for npc: Node in get_tree().get_nodes_in_group("cinematic_kick_back"):
			if npc.has_method("reset_patrol"):
				npc.reset_patrol()
		var kick_origin: Vector2 = player.global_position
		play_cinematic([
			{"type": "move_player", "to": Vector2(kick_origin.x, 240.0), "speed": 100.0},
			{"type": "move_player", "to": Vector2(64.0, 240.0), "speed": 100.0},
		], func():
			_on_exit_triggered("west")
		)
		return

	# Apply any post-interaction effects for the NPC whose dialog just ended.
	var npc: Node = _interacting_npc
	_interacting_npc = null
	if npc != null and not npc.is_queued_for_deletion():
		_handle_post_npc_dialog(npc)


## Apply post-dialog effects: give keys, accept keys, set game flags.
func _handle_post_npc_dialog(npc: Node) -> void:
	# NPC requires a key the player has → accept it and remove the NPC (gate opens).
	if npc.requires_key_id != "" and player.has_key(npc.requires_key_id):
		player.remove_key(npc.requires_key_id)
		npc.queue_free()
		return

	# NPC gives a key when its flag gate is satisfied → give key and remove NPC.
	if npc.gives_key_id != "":
		var flag: String = npc.gives_key_flag
		if flag == "" or GameState.has_flag(flag):
			player.inventory.append(npc.gives_key_id)
			player.keys_changed.emit(player.inventory.size())
			npc.queue_free()
			return

	# Normal interaction: set a game flag if configured.
	if npc.sets_game_flag != "":
		GameState.set_flag(npc.sets_game_flag)


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


func _update_key_display(count: int) -> void:
	if count > 0:
		key_label.text = "Key: %d" % count
		key_label.visible = true
	else:
		key_label.visible = false


func _update_rage_bar(value: float) -> void:
	rage_bar.value = value * 100.0


func _on_rage_attack() -> void:
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 15
	add_child(flash_layer)
	var flash_rect := ColorRect.new()
	flash_rect.color = Color(1.0, 0.4, 0.0, 0.7)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_layer.add_child(flash_rect)
	var tween := create_tween()
	tween.tween_interval(0.1)
	tween.tween_property(flash_rect, "color:a", 0.0, 0.3)
	tween.tween_callback(flash_layer.queue_free)


func _on_locked_exit_attempted(_direction: String, _key_id: String) -> void:
	if not dialog_box.is_active():
		_set_dialog_active(true)
		dialog_box.start_dialog(["It's locked."])


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


func _on_level_end_reached(trigger: Node) -> void:
	player.is_in_dialog = true
	var slides: Array = trigger.end_cutscene_slides
	# Level-specific end cutscenes (defined here because Dictionaries with Color
	# values cannot be serialised directly in .tscn property overrides).
	if slides.is_empty() and current_level_name == "level_1":
		slides = [
			{"image": null, "text": "Dudley boards the number 9 bus.\nIt takes him in completely the wrong direction.", "background_color": Color(0.1, 0.1, 0.1)},
			{"image": null, "text": "The bus deposits him — confusingly — in central London,\noutside a rather grubby pub he could have sworn\nwasn't there yesterday.", "background_color": Color(0.1, 0.1, 0.1)},
		]
	var _do_complete := func(): _show_level_complete(trigger)
	if slides.size() > 0:
		play_cutscene(slides, _do_complete)
	else:
		_do_complete.call()


func _on_boss_defeated() -> void:
	_show_level_complete()


func _show_level_complete(trigger: Node = null) -> void:
	GameState.mark_complete(current_level_name)
	var lc_scene: PackedScene = load("res://scenes/level_complete.tscn")
	var lc: Node = lc_scene.instantiate()
	lc.level_title = LEVELS[current_level_name].get("title", current_level_name)
	add_child(lc)
	lc.continue_pressed.connect(func():
		lc.queue_free()
		var next: String = ""
		if trigger != null and "next_level" in trigger:
			next = trigger.next_level
		if next == "":
			next = LEVELS[current_level_name].get("next_level", "")
		if next != "" and next in LEVELS:
			_load_level(next)
		else:
			get_tree().change_scene_to_file("res://scenes/level_select.tscn")
	)


func play_cinematic(sequence: Array, on_finish: Callable) -> void:
	if _cinematic_player == null:
		_cinematic_player = Node.new()
		_cinematic_player.set_script(load("res://scripts/cinematic_player.gd"))
		add_child(_cinematic_player)
	_cinematic_player.sequence_finished.connect(on_finish, CONNECT_ONE_SHOT)
	_cinematic_player.play(sequence, current_room, player, dialog_box)


func play_cutscene(slides: Array, on_finish: Callable) -> void:
	var cutscene_scene: PackedScene = load("res://scenes/cutscene.tscn")
	var cutscene: Node = cutscene_scene.instantiate()
	add_child(cutscene)
	cutscene.cutscene_finished.connect(func():
		on_finish.call()
		cutscene.queue_free()
	)
	cutscene.play(slides)
