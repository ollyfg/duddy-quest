extends Node2D

const _HEART_FULL: Texture2D = preload("res://assets/icons/heart_full.svg")
const _HEART_EMPTY: Texture2D = preload("res://assets/icons/heart_empty.svg")
# Each level groups its rooms, connections, starting room and starting position.
const LEVELS: Dictionary = {
	"level_1": {
		"title": "A Perfectly Normal Catastrophe",
		"next_level": "",
		"start_room": "l1_bedroom",
		"start_pos": Vector2(80.0, 240.0),
		"rooms": {
			"l1_bedroom": preload("res://scenes/l1_bedroom.tscn"),
			"l1_dining_room": preload("res://scenes/l1_dining_room.tscn"),
			"l1_upper_hall": preload("res://scenes/l1_upper_hall.tscn"),
			"l1_hallway": preload("res://scenes/l1_hallway.tscn"),
			"l1_front_hall": preload("res://scenes/l1_front_hall.tscn"),
			"l1_garden": preload("res://scenes/l1_garden.tscn"),
			"l1_street": preload("res://scenes/l1_street.tscn"),
			"l1_vernon_room": preload("res://scenes/l1_vernon_room.tscn"),
		},
		"connections": {
			"l1_bedroom": {
				"east": {"room": "l1_upper_hall", "entry": Vector2(64.0, 160.0)},
			},
			"l1_upper_hall": {
				"west": {"room": "l1_bedroom", "entry": Vector2(576.0, 160.0)},
				"east": {"room": "l1_hallway", "entry": Vector2(64.0, 320.0)},
				"north": {"room": "l1_vernon_room", "entry": Vector2(192.0, 416.0)},
			},
			"l1_vernon_room": {
				"south": {"room": "l1_upper_hall", "entry": Vector2(192.0, 64.0)},
			},
			"l1_hallway": {
				"west": {"room": "l1_upper_hall", "entry": Vector2(576.0, 320.0)},
				"east": {"room": "l1_front_hall", "entry": Vector2(64.0, 160.0)},
			},
			"l1_front_hall": {
				"west": {"room": "l1_hallway", "entry": Vector2(576.0, 160.0)},
				"east": {"room": "l1_garden", "entry": Vector2(64.0, 320.0)},
			},
			"l1_garden": {
				"west": {"room": "l1_front_hall", "entry": Vector2(576.0, 320.0)},
				"east": {"room": "l1_street", "entry": Vector2(64.0, 160.0)},
			},
			"l1_street": {
				"west": {"room": "l1_garden", "entry": Vector2(576.0, 160.0)},
			},
		},
	},
}

var current_level_name: String = ""
var current_room_name: String = ""
# Untyped to allow calling room.gd helper APIs (get_npcs, get_items,
# get_switches, get_first_npc_path, get_room_rect, and room signals).
var current_room = null
# Persists room state (surviving NPC positions/HP) across room transitions.
var _room_states: Dictionary = {}

@onready var room_holder: Node2D = $RoomHolder
# Untyped to allow accessing player.gd custom signals and properties.
@onready var player = $Player
# Untyped to allow calling dialog_box.gd methods (is_active, start_dialog).
@onready var dialog_box = $HUD/DialogBox
@onready var hp_bar: HBoxContainer = $HUD/HPBar
@onready var key_label: Label = $HUD/KeyLabel
@onready var rage_bar: ProgressBar = $HUD/RageBar
@onready var mobile_controls = $MobileControls

var _cinematic_player: Node = null
const _CINEMATIC_PLAYER_SCRIPT: Script = preload("res://scripts/cinematic_player.gd")
## Action to run when dialog closes (used for player catch/kickback flows).
enum PostDialogAction { NONE, GO_WEST, PETUNIA_KICK }
var _post_dialog_action: int = PostDialogAction.NONE
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
	_init_hp_bar()

	# Allow launching into a specific level via --level <name> CLI argument;
	# otherwise use the level chosen on the level-select screen.
	var args := OS.get_cmdline_user_args()
	# Fall back to level_1 if the stored level is missing from LEVELS.
	var level_name: String = GameState.selected_level if GameState.selected_level in LEVELS else "level_1"
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
	if level_name == "level_1":
		play_cutscene([
			{"image": null, "text": "4 PRIVET DRIVE, LITTLE WHINGING\nA perfectly normal Saturday morning.", "background_color": Color(0.12, 0.08, 0.04)},
			{"image": null, "text": "You are DUDLEY DURSLEY.\nYou have just found an unopened Hogwarts letter\nhidden in Aunt Petunia's shoebox.", "background_color": Color(0.12, 0.08, 0.04)},
			{"image": null, "text": "Smeltings stick in hand, you are about to take\nthe most roundabout path to Hogwarts\nin the school's nine-hundred-year history.", "background_color": Color(0.12, 0.08, 0.04)},
		], func(): _start_level_1_intro())
	else:
		_load_room(level["start_room"], level["start_pos"])


## Plays the level-1 dining-room intro cinematic then loads the bedroom.
## Called after the opening text cutscene finishes.
func _start_level_1_intro() -> void:
	await _load_room("l1_dining_room", Vector2(448.0, 304.0))
	play_cinematic([
		{"type": "dialog", "speaker": "Vernon", "lines": [
			"Fine day, Sunday. In my opinion, best day of the week. Why is that, Dudley?",
		]},
		{"type": "wait", "duration": 0.8},
		{"type": "dialog", "speaker": "Harry", "lines": [
			"Because there's no post on Sundays?",
		]},
		{"type": "dialog", "speaker": "Vernon", "lines": [
			"Right you are, Harry! No post on Sunday. No blasted letters today! No, sir. Not one single bloody letter. Not one! No, sir, not one blasted, miserable\u2026",
		]},
		{"type": "set_visible", "node": "FlyingLetters", "visible": true},
		{"type": "wait", "duration": 0.5},
		{"type": "dialog", "speaker": "Harry", "lines": [
			"Whoopee!",
		]},
		{"type": "dialog", "speaker": "", "lines": [
			"Letters everywhere. Hundreds of them. All addressed to POTTER.",
			"But wait. This one says\u2026",
			"'D. DURSLEY (THE LARGER ONE).'",
			"That's ME. Hogwarts wants ME.",
		]},
		{"type": "wait", "duration": 0.5},
	], func():
		_load_room(LEVELS["level_1"]["start_room"], LEVELS["level_1"]["start_pos"])
	)


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
		# Teleport the player to the entry position, then wait one physics
		# frame so that Godot's physics broadphase fully commits the new body
		# position before the new room's exit Area2D nodes are registered.
		# Without this wait the broadphase may still hold the player's position
		# from the previous room, causing the new room's exits to fire a
		# spurious body_entered on their very first overlap check.
		player.global_position = player_pos
		player.cancel_movement()
		await get_tree().physics_frame
	else:
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
		if trigger.has_signal("level_end_reached") and not trigger.has_meta("_duddy_level_end_connected"):
			trigger.level_end_reached.connect(_on_level_end_reached.bind(trigger))
			trigger.set_meta("_duddy_level_end_connected", true)

	# Restore saved state (remove dead NPCs, reapply positions/HP) before
	# connecting any signals so we never wire up nodes about to be freed.
	_restore_room_state(room_name)

	# Give NPCs a reference to the player for hostile chase behaviour.
	# Connect friendly NPC interaction signals.
	for npc in current_room.get_npcs():
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

	# Keep transition guard active for one additional physics frame after the
	# new room is instantiated.  On some runs Godot can emit an exit
	# body_entered on that first frame from stale broadphase overlap data,
	# which would immediately chain into a second room transition.
	await get_tree().physics_frame
	_room_loading = false

	# Trigger first-visit intro cinematics.
	if room_name == "l1_hallway" and not GameState.l1_hallway_intro_shown:
		_play_hallway_intro()
	elif room_name == "l1_street" and not GameState.l1_street_intro_shown:
		_play_street_intro()

## Snapshot the current room's NPC, item, and switch states before transitioning away.
func _save_room_state() -> void:
	if current_room == null or current_room_name == "":
		return
	var npc_states: Dictionary = {}
	for npc in current_room.get_npcs():
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
	for item in current_room.get_items():
		if not item.is_queued_for_deletion():
			item_names.append(item.name)
	# Switches: record each switch's current on/off state.
	var switch_states: Dictionary = {}
	for sw in current_room.get_switches():
		switch_states[sw.name] = sw.is_on
	# Magic doors: remember whether each one has already been opened/destroyed.
	var magic_door_states: Dictionary = {}
	for door in current_room.find_children("*", "StaticBody2D", true, false):
		if door.has_method("on_rage_attack") and door.has_signal("door_opened"):
			magic_door_states[door.name] = not door.visible
	_room_states[current_room_name] = {
		"npcs": npc_states,
		"items": item_names,
		"switches": switch_states,
		"magic_doors": magic_door_states,
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
	if "npcs" in state:
		var npc_states: Dictionary = state["npcs"]
		for npc in current_room.get_npcs():
			if npc.name not in npc_states:
				npc.queue_free()
			else:
				var npc_data: Dictionary = npc_states[npc.name]
				npc.global_position = npc_data["position"]
				npc.hp = npc_data["hp"]
	# Restore items: remove any item that was already collected.
	if "items" in state:
		var present_items: Array[String] = state["items"]
		for item in current_room.get_items():
			if item.name not in present_items:
				item.queue_free()
	# Restore switches: call on_hit() for any switch whose saved state differs
	# from its starting state so the visual, door, and locked-exit are updated.
	# on_hit() is called at most once per switch (the condition guarantees this),
	# toggling from starts_on to the saved state in a single authorized step.
	if "switches" in state:
		var switch_states: Dictionary = state["switches"]
		for sw in current_room.get_switches():
			if sw.name in switch_states and sw.is_on != switch_states[sw.name]:
				sw.on_hit()
	# Restore magic doors: opened/destroyed doors should stay removed.
	if "magic_doors" in state:
		var door_states: Dictionary = state["magic_doors"]
		for door_name: String in door_states:
			var door: Node = current_room.get_node_or_null(door_name)
			if door == null:
				continue
			var opened: bool = door_states[door_name]
			door.visible = not opened
			var collision: CollisionShape2D = door.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if collision != null:
				collision.set_deferred("disabled", opened)


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
	dialog_box.set_speaker(npc.npc_name)
	dialog_box.start_dialog(_pick_npc_dialog(npc))


## Choose the correct dialog lines for an NPC, respecting flag gates and
## key-requirement states.
func _pick_npc_dialog(npc: Node) -> Array:
	# Key-accepting NPC and the player already carries the required key.
	if npc.requires_key_id != "" and player.has_key(npc.requires_key_id):
		return npc.key_accept_dialog if not npc.key_accept_dialog.is_empty() else npc.dialog_lines

	# NPC with after_key_dialog: switch to meow/short lines once the player
	# has already found the associated key item.
	if npc.after_key_id != "" and player.has_key(npc.after_key_id):
		return npc.after_key_dialog if not npc.after_key_dialog.is_empty() else npc.dialog_lines

	# Work out whether any flag gate applies to this NPC.
	var gate_flag: String = ""
	if npc.gives_key_id != "":
		gate_flag = npc.gives_key_flag
	if gate_flag == "" and npc.requires_flag != "":
		gate_flag = npc.requires_flag

	if gate_flag != "" and not GameState.has_flag(gate_flag):
		return npc.pre_flag_dialog if not npc.pre_flag_dialog.is_empty() else ["..."]

	# If the NPC has random dialog pools, pick one and append it to the base lines.
	if not npc.dialog_pools.is_empty():
		var pool: Array = npc.dialog_pools.pick_random()
		return npc.dialog_lines + pool + npc.dialog_suffix

	return npc.dialog_lines + npc.dialog_suffix


## Called when a PATROL NPC spots the player for the first time this room visit.
## Shows the NPC's detection line as a warning; Petunia begins chasing but the
## player is only sent back if she physically catches them (cinematic_kick_back).
func _on_npc_player_detected(dialog: String) -> void:
	if dialog_box.is_active() or _post_dialog_action != PostDialogAction.NONE:
		return
	_set_dialog_active(true)
	dialog_box.set_speaker("")
	dialog_box.start_dialog([dialog])


func _on_bedroom_door_approached() -> void:
	if GameState.l1_bedroom_door_hint_shown or dialog_box.is_active():
		return
	GameState.l1_bedroom_door_hint_shown = true
	_set_dialog_active(true)
	dialog_box.set_speaker("")
	dialog_box.start_dialog([
		"You try to open the door but it's locked.",
		"Maybe if you whack it enough...",
	])


## Called when Petunia's HitArea physically contacts the player.
## Shows her catch line then plays a cinematic marching the player back to the
## hallway's west exit before loading the previous room.
func _on_petunia_hit_player() -> void:
	if _room_loading or player.cinematic_mode or dialog_box.is_active() or _post_dialog_action != PostDialogAction.NONE:
		return
	_post_dialog_action = PostDialogAction.PETUNIA_KICK
	_set_dialog_active(true)
	dialog_box.set_speaker("Petunia")
	var catch_phrases: Array = [
		"Back to your room, DUDDIKINS!",
		"Oh NO you don't, young man! BACK!",
		"Dudley Dursley! Where do you think YOU'RE going?!",
		"NOT one more step! Your father will hear about this!",
		"You'll spoil your APPETITE! GET BACK HERE!",
	]
	dialog_box.start_dialog([catch_phrases.pick_random()])


func _on_dialog_ended() -> void:
	_set_dialog_active(false)
	var action: int = _post_dialog_action
	_post_dialog_action = PostDialogAction.NONE

	# A "go_west" post-dialog action takes priority (Petunia sending player back).
	if action == PostDialogAction.GO_WEST:
		_interacting_npc = null
		_on_exit_triggered("west")
		return

	# Petunia catches the player: cinematic marching them back to the bedroom door.
	if action == PostDialogAction.PETUNIA_KICK:
		_interacting_npc = null
		# Return Petunia (and any other cinematic_kick_back NPC) to her patrol
		# route immediately so she doesn't continue chasing during the escort.
		for npc: Node in get_tree().get_nodes_in_group("cinematic_kick_back"):
			if npc.has_method("reset_patrol"):
				npc.reset_patrol()
		var kick_origin: Vector2 = player.global_position
		play_cinematic([
			{"type": "move_player", "to": Vector2(kick_origin.x, 320.0), "speed": 100.0},
			{"type": "move_player", "to": Vector2(64.0, 320.0), "speed": 100.0},
		], func():
			_on_exit_triggered("west")
		)
		return

	# Apply any post-interaction effects for the NPC whose dialog just ended.
	var npc: Node = _interacting_npc
	_interacting_npc = null
	if npc != null and is_instance_valid(npc):
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
	if current_room:
		# Keep NPCs paused during an active cinematic; only fully unpause when
		# both dialog ends AND no cinematic is playing.
		var should_pause: bool = active or player.cinematic_mode
		for npc in current_room.get_npcs():
			npc.is_paused = should_pause


func _init_hp_bar() -> void:
	for i: int in range(player.MAX_HP):
		var tr := TextureRect.new()
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(28, 28)
		hp_bar.add_child(tr)
	_update_hp_display(player.hp)


func _update_hp_display(new_hp: int) -> void:
	for i: int in range(hp_bar.get_child_count()):
		var tr: TextureRect = hp_bar.get_child(i)
		tr.texture = _HEART_FULL if i < new_hp else _HEART_EMPTY


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
		dialog_box.set_speaker("")
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
		_cinematic_player.set_script(_CINEMATIC_PLAYER_SCRIPT)
		add_child(_cinematic_player)
	_cinematic_player.sequence_finished.connect(on_finish, CONNECT_ONE_SHOT)
	_cinematic_player.play(sequence, current_room, player, dialog_box)


## First-time intro for the hallway: Petunia paces while muttering to herself.
func _play_hallway_intro() -> void:
	GameState.l1_hallway_intro_shown = true
	_set_dialog_active(true)
	play_cinematic([
		{"type": "pan_camera", "to": Vector2(320.0, 240.0), "duration": 1.2},
		{"type": "dialog", "speaker": "Petunia", "lines": [
			"Breathe. Everything is fine.",
			"A good vacuum, that's what we need.",
			"Everything will be fine if I just keep cleaning.",
		]},
		{"type": "reset_camera", "duration": 0.8},
	], func() -> void: _finish_room_intro())


## First-time intro for the street: Piers and his gang scheme against Dudley.
func _play_street_intro() -> void:
	GameState.l1_street_intro_shown = true
	_set_dialog_active(true)
	play_cinematic([
		{"type": "pan_camera", "to": Vector2(416.0, 256.0), "duration": 1.2},
		{"type": "dialog", "speaker": "Piers", "lines": [
			"Did you see Dudley sneaking off with that letter?",
			"'Hogwarts School of Witchcraft and Wizardry.' Ha!",
		]},
		{"type": "dialog", "speaker": "Gang Member", "lines": [
			"Witchcraft? Like his cousin Potter?",
		]},
		{"type": "dialog", "speaker": "Piers", "lines": [
			"Looks like Dudders wants to join the freaks.",
			"Can't have that — he'll ruin our reputation.",
			"Teach him a lesson, lads.",
			"Remind him where he belongs.",
		]},
		{"type": "reset_camera", "duration": 0.8},
	], func() -> void: _finish_room_intro())


## Shared cleanup called when any room intro cinematic finishes.
func _finish_room_intro() -> void:
	_set_dialog_active(false)
	player.set_camera_limits(current_room.get_room_rect())


func play_cutscene(slides: Array, on_finish: Callable) -> void:
	var cutscene_scene: PackedScene = load("res://scenes/cutscene.tscn")
	var cutscene: Node = cutscene_scene.instantiate()
	add_child(cutscene)
	cutscene.cutscene_finished.connect(func():
		on_finish.call()
		cutscene.queue_free()
	)
	cutscene.play(slides)
