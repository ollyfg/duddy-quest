extends Node
## Manages the room lifecycle: loading, saving/restoring state, exit handling,
## and A* pathfinding for the current room.

var current_room = null
var current_room_name: String = ""
## Persists room state (surviving NPC positions/HP) across room transitions.
var _room_states: Dictionary = {}
## Guards against re-entrant _on_exit_triggered calls during the one-frame
## await in load_room.
var _room_loading: bool = false
## A* pathfinder for the current room; rebuilt each time a room loads.
## Null in rooms where no NPC has use_astar enabled.
## Untyped because the pathfinder script has no class_name registered.
var _current_pathfinder = null

## Untyped to allow accessing player.gd custom signals and properties.
var _player
var _room_holder: Node2D
## Reference to main.gd for LEVELS, current_level_name, and sibling managers.
var _main: Node

const _PATHFINDER_SCRIPT: Script = preload("res://scripts/pathfinder.gd")

## Duration (seconds) of the camera slide during a room transition.
const TRANSITION_DURATION: float = 0.4


func setup(player, room_holder: Node2D, main: Node) -> void:
	_player = player
	_room_holder = room_holder
	_main = main


## Returns the current room's A* pathfinder (may be null).
func get_pathfinder():
	return _current_pathfinder


## Returns true while a room transition is in progress.
func is_loading() -> bool:
	return _room_loading


## Clears all saved room-state snapshots (called at level start).
func clear_room_states() -> void:
	_room_states.clear()


## Programmatically trigger an exit in the given direction; used by
## dialog_manager after post-dialog cinematic flows.
func trigger_exit(direction: String) -> void:
	_on_exit_triggered(direction)


func load_room(room_name: String, player_pos: Vector2) -> void:
	_room_loading = true
	if current_room:
		_save_room_state()
		# Disconnect the old room's exit signals first so that any in-flight
		# physics body_entered callbacks queued on the old room's exit Area2D
		# nodes cannot fire _on_exit_triggered in the new room's context.
		if current_room.exit_triggered.is_connected(_on_exit_triggered):
			current_room.exit_triggered.disconnect(_on_exit_triggered)
		if current_room.locked_exit_attempted.is_connected(_main.dialog_manager.on_locked_exit_attempted):
			current_room.locked_exit_attempted.disconnect(_main.dialog_manager.on_locked_exit_attempted)
		current_room.queue_free()
		await get_tree().process_frame
		# Teleport the player to the entry position, then wait one physics
		# frame so that Godot's physics broadphase fully commits the new body
		# position before the new room's exit Area2D nodes are registered.
		_player.global_position = player_pos
		_player.cancel_movement()
		await get_tree().physics_frame
	else:
		_player.global_position = player_pos
		_player.cancel_movement()

	current_room_name = room_name
	var level_rooms: Dictionary = _main.LEVELS[_main.current_level_name]["rooms"]
	var scene_path: String = level_rooms.get(room_name, "")
	if scene_path == "":
		push_error("room_manager: no scene path for room '%s' in level '%s'" % [room_name, _main.current_level_name])
		_room_loading = false
		return
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("room_manager: failed to load scene '%s' for room '%s'" % [scene_path, room_name])
		_room_loading = false
		return
	current_room = packed.instantiate()
	_room_holder.add_child(current_room)
	current_room.exit_triggered.connect(_on_exit_triggered)
	current_room.locked_exit_attempted.connect(_main.dialog_manager.on_locked_exit_attempted)

	# Connect level-end triggers.
	for trigger in get_tree().get_nodes_in_group("level_end"):
		if trigger.has_signal("level_end_reached") and not trigger.has_meta("_duddy_level_end_connected"):
			trigger.level_end_reached.connect(_main.level_manager._on_level_end_reached.bind(trigger))
			trigger.set_meta("_duddy_level_end_connected", true)

	# Restore saved state before connecting signals so we never wire up nodes
	# about to be freed.
	_restore_room_state(room_name)

	# Give NPCs a reference to the player and connect interaction signals.
	for npc in current_room.get_npcs():
		if npc.is_queued_for_deletion():
			continue
		if npc.has_method("set_player_reference"):
			npc.set_player_reference(_player)
		if npc.has_method("set_room_bounds"):
			npc.set_room_bounds(current_room.get_room_rect())
		_wire_npc_signals(npc, room_name)

	_player.set_camera_limits(current_room.get_room_rect())
	_main.hud_manager.update_hp_display(_player.hp)
	_main.hud_manager.update_wand_display()

	# Connect the bedroom door hint signal (fires first time player bumps door).
	if room_name == "l1_bedroom":
		var door: Node = current_room.get_node_or_null("MagicDoor")
		if door != null and door.has_signal("door_approached"):
			door.door_approached.connect(_main.dialog_manager.on_bedroom_door_approached)

	# Keep transition guard active for one additional physics frame after the
	# new room is instantiated to prevent spurious re-entry.
	await get_tree().physics_frame
	_room_loading = false

	# Build (or clear) the A* pathfinder once all physics bodies are registered.
	_rebuild_pathfinder()

	# Trigger first-visit intro cinematics.
	if room_name == "l1_hallway" and not GameState.has_flag("l1_hallway_intro_shown"):
		_main._play_hallway_intro()
	elif room_name == "l1_street" and not GameState.has_flag("l1_street_intro_shown"):
		_main._play_street_intro()
	elif room_name == "l2_leaky_cauldron" and not GameState.has_flag("l2_leaky_cauldron_intro_shown"):
		_main._play_leaky_cauldron_intro()


## Snapshot the current room's NPC, item, and switch states before
## transitioning away.
func _save_room_state() -> void:
	if current_room == null or current_room_name == "":
		return
	var npc_states: Dictionary = {}
	for npc in current_room.get_npcs():
		# Skip NPCs that have already been removed (e.g. picked-up cats).
		if npc.is_queued_for_deletion():
			continue
		npc_states[npc.name] = {
			"position": npc.global_position - current_room.global_position,
			"hp": npc.hp,
		}
	# Items: record the names of items that are still present.
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
				npc.global_position = current_room.global_position + npc_data["position"]
				npc.hp = npc_data["hp"]
	# Restore items: remove any item that was already collected.
	if "items" in state:
		var present_items: Array[String] = state["items"]
		for item in current_room.get_items():
			if item.name not in present_items:
				item.queue_free()
	# Restore switches: call on_hit() for any switch whose saved state differs
	# from its starting state.
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
	# Guard against re-entrant calls while a room transition is already in progress.
	if _room_loading:
		return
	if current_room_name not in _main.LEVELS[_main.current_level_name]["connections"]:
		return
	var connections: Dictionary = _main.LEVELS[_main.current_level_name]["connections"][current_room_name]
	if direction not in connections:
		return
	var next: Dictionary = connections[direction]
	_start_room_transition(direction, next["room"], next["entry"])


## Seamless camera-scroll transition: loads the new room adjacent to the old
## room so both are simultaneously visible during the slide.  This eliminates
## the dark gap that occurred with the old two-phase approach.
##
## Flow:
##   1. Instantiate new room at a world offset adjacent to the old room.
##   2. Teleport the player to the entry position in the new room.
##   3. Compensate the camera offset so the viewport appears to stay still.
##   4. Wire signals / NPCs for the new room.
##   5. Tween camera offset from the compensated value back to zero — the
##      camera glides smoothly from the old exit to the new entry while both
##      rooms are rendered.
##   6. After the tween, free the old room and restore camera limits.
func _start_room_transition(direction: String, room_name: String, player_pos: Vector2) -> void:
	_room_loading = true
	_player.cinematic_mode = true
	_player.cancel_movement()

	# Pause all NPCs in the outgoing room so they do not wander during the
	# slide.  The old room is freed after the tween, so no explicit unpause is
	# needed for those NPCs.
	if current_room != null:
		for npc in current_room.get_npcs():
			if not npc.is_queued_for_deletion():
				npc.is_paused = true

	var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	var old_room = current_room

	# ── Load the new room adjacent to the old one ─────────────────────────────
	var level_rooms: Dictionary = _main.LEVELS[_main.current_level_name]["rooms"]
	var scene_path: String = level_rooms.get(room_name, "")
	if scene_path == "":
		push_error("room_manager: no scene path for room '%s' in level '%s'" % [room_name, _main.current_level_name])
		_room_loading = false
		return
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("room_manager: failed to load scene '%s' for room '%s'" % [scene_path, room_name])
		_room_loading = false
		return
	var new_room = packed.instantiate()
	# Position the new room immediately adjacent to the old room so the camera
	# can scroll seamlessly between them with no black gap.
	var room_offset: Vector2 = _compute_adjacent_offset(direction, old_room, new_room.room_size)
	new_room.position = room_offset
	_room_holder.add_child(new_room)

	# ── Save state and disconnect signals from the old room ───────────────────
	if old_room != null:
		_save_room_state()
		if old_room.exit_triggered.is_connected(_on_exit_triggered):
			old_room.exit_triggered.disconnect(_on_exit_triggered)
		if old_room.locked_exit_attempted.is_connected(_main.dialog_manager.on_locked_exit_attempted):
			old_room.locked_exit_attempted.disconnect(_main.dialog_manager.on_locked_exit_attempted)

	# ── Teleport player; compensate camera so viewport appears stationary ─────
	var new_player_world_pos: Vector2 = room_offset + player_pos
	# Capture the camera's *actual* screen-centre position before any changes.
	# This accounts for limit clamping — if the player was near a room edge
	# the camera may not have been centered on the player.
	var old_cam_center: Vector2 = cam.get_screen_center_position() if cam != null else _player.global_position
	_player.global_position = new_player_world_pos
	_player.cancel_movement()
	if cam != null:
		cam.position_smoothing_enabled = false
		cam.limit_left = -GameConfig.UNLIMITED_CAMERA_LIMIT
		cam.limit_top = -GameConfig.UNLIMITED_CAMERA_LIMIT
		cam.limit_right = GameConfig.UNLIMITED_CAMERA_LIMIT
		cam.limit_bottom = GameConfig.UNLIMITED_CAMERA_LIMIT
		# The camera's world target is: player.global_position + cam.position + cam.offset
		# We want that to equal old_cam_center so the viewport stays still.
		cam.offset = old_cam_center - new_player_world_pos - cam.position

	# One physics frame so the new room's collision bodies are registered
	# before we wire exit signals to the new room.
	await get_tree().physics_frame

	# ── Wire up the new room ───────────────────────────────────────────────────
	current_room_name = room_name
	current_room = new_room
	current_room.exit_triggered.connect(_on_exit_triggered)
	current_room.locked_exit_attempted.connect(_main.dialog_manager.on_locked_exit_attempted)

	for trigger in get_tree().get_nodes_in_group("level_end"):
		if trigger.has_signal("level_end_reached") and not trigger.has_meta("_duddy_level_end_connected"):
			trigger.level_end_reached.connect(_main.level_manager._on_level_end_reached.bind(trigger))
			trigger.set_meta("_duddy_level_end_connected", true)

	_restore_room_state(room_name)

	for npc in current_room.get_npcs():
		if npc.is_queued_for_deletion():
			continue
		npc.is_paused = true  # Stay paused until the camera slide finishes.
		if npc.has_method("set_player_reference"):
			npc.set_player_reference(_player)
		if npc.has_method("set_room_bounds"):
			npc.set_room_bounds(current_room.get_room_rect())
		_wire_npc_signals(npc, room_name)

	_main.hud_manager.update_hp_display(_player.hp)
	_main.hud_manager.update_wand_display()

	if room_name == "l1_bedroom":
		var door: Node = current_room.get_node_or_null("MagicDoor")
		if door != null and door.has_signal("door_approached"):
			door.door_approached.connect(_main.dialog_manager.on_bedroom_door_approached)

	# Second physics frame: ensure all signal connections and NPC setup from
	# this frame are fully committed before clearing the loading guard.
	await get_tree().physics_frame
	_room_loading = false
	_rebuild_pathfinder()

	# ── Check for first-visit intro cinematics ────────────────────────────────
	# Trigger any intro that applies; the cinematic manages the camera itself
	# (pan_camera / reset_camera), so we skip the slide and hand off control.
	_room_loading = true
	if room_name == "l1_hallway" and not GameState.has_flag("l1_hallway_intro_shown"):
		_main._play_hallway_intro()
	elif room_name == "l1_street" and not GameState.has_flag("l1_street_intro_shown"):
		_main._play_street_intro()
	elif room_name == "l2_leaky_cauldron" and not GameState.has_flag("l2_leaky_cauldron_intro_shown"):
		_main._play_leaky_cauldron_intro()
	elif room_name == "l2_alley_end" \
			and GameState.has_flag("l2_has_wand") \
			and not GameState.has_flag("l2_draco_defeated") \
			and not GameState.has_flag("l2_draco_fight_intro_shown"):
		_main._play_draco_intro_cinematic()

	if _main.is_cinematic_playing():
		# Snap camera to the new room immediately; the cinematic will
		# override it on its first step anyway.
		if cam != null:
			cam.offset = Vector2.ZERO
			cam.position_smoothing_enabled = false
			_player.set_camera_limits(current_room.get_room_rect())
		if old_room != null and is_instance_valid(old_room):
			old_room.queue_free()
		for npc in current_room.get_npcs():
			if not npc.is_queued_for_deletion():
				npc.is_paused = false
		_room_loading = false
		# cinematic_player.gd resets cinematic_mode when the sequence ends.
		return

	# ── Camera slide: glide from the compensated offset to zero ──────────────
	# Both rooms are still in the scene; the viewport shows a smooth scroll
	# from the old exit to the new entry with no black frames.
	if cam != null:
		var tween: Tween = cam.create_tween()
		tween.tween_property(cam, "offset", Vector2.ZERO, TRANSITION_DURATION) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished

	# ── Finalise: free old room, restore camera limits, unpause NPCs ──────────
	if old_room != null and is_instance_valid(old_room):
		old_room.queue_free()
	if cam != null:
		cam.position_smoothing_enabled = true
		_player.set_camera_limits(current_room.get_room_rect())
	for npc in current_room.get_npcs():
		if not npc.is_queued_for_deletion():
			npc.is_paused = false
	_room_loading = false
	_player.cinematic_mode = false


## Returns the world-space position at which the new room should be placed so
## it sits flush against the corresponding edge of the old room.
func _compute_adjacent_offset(direction: String, old_room: Node2D, new_room_size: Vector2) -> Vector2:
	if old_room == null:
		return Vector2.ZERO
	var old_pos: Vector2 = old_room.global_position
	var old_size: Vector2 = old_room.room_size
	match direction:
		"east":  return old_pos + Vector2(old_size.x, 0.0)
		"west":  return old_pos + Vector2(-new_room_size.x, 0.0)
		"south": return old_pos + Vector2(0.0, old_size.y)
		"north": return old_pos + Vector2(0.0, -new_room_size.y)
	return old_pos


## Builds an A* pathfinder for the current room if any NPC in it has
## use_astar enabled, then distributes the pathfinder to those NPCs.
func _rebuild_pathfinder() -> void:
	_current_pathfinder = null
	if current_room == null:
		return
	var needs_astar: bool = false
	for npc: Node in current_room.get_npcs():
		if npc.get("use_astar"):
			needs_astar = true
			break
	if not needs_astar:
		return
	var pathfinder = _PATHFINDER_SCRIPT.new()
	pathfinder.build(_main.get_world_2d().direct_space_state, current_room.global_position, current_room.room_size)
	_current_pathfinder = pathfinder
	for npc: Node in current_room.get_npcs():
		if npc.get("use_astar") and npc.has_method("set_pathfinder"):
			npc.set_pathfinder(_current_pathfinder)


## Connect all interaction signals for a single NPC.  Called from both
## load_room() and _start_room_transition() to avoid duplicating the logic.
func _wire_npc_signals(npc: Node, room_name: String) -> void:
	if npc.is_in_group("boss") and npc.has_signal("boss_defeated"):
		npc.boss_defeated.connect(_main.level_manager._on_boss_defeated)
		npc.interaction_requested.connect(_main.dialog_manager.on_npc_interaction_requested.bind(npc))
	elif not npc.is_hostile:
		if room_name == "l2_ollivanders" and npc.get("npc_name") == "Mr Ollivander":
			npc.interaction_requested.connect(_main._on_ollivander_interaction_requested)
		else:
			npc.interaction_requested.connect(_main.dialog_manager.on_npc_interaction_requested.bind(npc))
	if npc.detection_dialog != "":
		npc.player_detected.connect(_main.dialog_manager.on_npc_player_detected)
	if npc.cinematic_kick_back:
		npc.add_collision_exception_with(_player)
		_player.add_collision_exception_with(npc)
		npc.player_hit.connect(_main.dialog_manager.on_petunia_hit_player)
	# Leaky Cauldron patrons: trigger bar fight when any patron is attacked.
	if room_name == "l2_leaky_cauldron" and npc.name.begins_with("Patron"):
		npc.damaged.connect(_main._on_patron_damaged)
