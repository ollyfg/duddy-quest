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

## Duration (seconds) of each slide phase (out and in) during a room transition.
const TRANSITION_DURATION: float = 0.4
## Slide distance for east/west exits: half the standard room width (512 px) at
## the default 2× zoom gives exactly one viewport-width of travel (256 world
## units → 512 screen pixels at zoom=2).  Adjust if room sizes change.
const TRANSITION_SLIDE_H: float = 256.0
## Slide distance for north/south exits: half the standard room height (384 px).
const TRANSITION_SLIDE_V: float = 192.0


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
		if npc.is_in_group("boss") and npc.has_signal("boss_defeated"):
			npc.boss_defeated.connect(_main.level_manager._on_boss_defeated)
			npc.interaction_requested.connect(_main.dialog_manager.on_npc_interaction_requested.bind(npc))
		elif not npc.is_hostile:
			npc.interaction_requested.connect(_main.dialog_manager.on_npc_interaction_requested.bind(npc))
		if npc.detection_dialog != "":
			npc.player_detected.connect(_main.dialog_manager.on_npc_player_detected)
		# Any NPC with cinematic_kick_back set triggers the Petunia
		# kick-back cinematic when it physically contacts the player.
		if npc.cinematic_kick_back:
			npc.add_collision_exception_with(_player)
			_player.add_collision_exception_with(npc)
			npc.player_hit.connect(_main.dialog_manager.on_petunia_hit_player)

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
			"position": npc.global_position,
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
				npc.global_position = npc_data["position"]
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


## Camera slide transition: freeze everything, slide the camera toward the exit,
## load the new room, then slide the camera in from the opposite direction.
func _start_room_transition(direction: String, room_name: String, player_pos: Vector2) -> void:
	_room_loading = true
	_player.cinematic_mode = true
	_player.cancel_movement()

	# Pause all NPCs in the outgoing room during the slide so they do not
	# wander while the camera is animating.  They will be freed when the old
	# room is queue_free()'d inside load_room(), so no explicit unpause is
	# needed.
	if current_room != null:
		for npc in current_room.get_npcs():
			if not npc.is_queued_for_deletion():
				npc.is_paused = true

	var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	var slide_vec: Vector2 = _get_transition_vector(direction)

	# Phase 1 — slide the camera toward the exit.
	if cam != null:
		cam.position_smoothing_enabled = false
		cam.limit_left = -GameConfig.UNLIMITED_CAMERA_LIMIT
		cam.limit_top = -GameConfig.UNLIMITED_CAMERA_LIMIT
		cam.limit_right = GameConfig.UNLIMITED_CAMERA_LIMIT
		cam.limit_bottom = GameConfig.UNLIMITED_CAMERA_LIMIT
		var tween_out: Tween = cam.create_tween()
		tween_out.tween_property(cam, "offset", slide_vec, TRANSITION_DURATION) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween_out.finished

	# Load the new room (saves old state, frees old room, teleports player,
	# instantiates new room).  load_room sets _room_loading = false at its end.
	await load_room(room_name, player_pos)

	# Re-acquire the transition lock for the slide-in phase.  load_room()
	# releases it at its end; we grab it again to prevent the player from
	# triggering a second exit before the camera has finished settling.
	_room_loading = true

	# If a first-visit intro cinematic started during load_room it will manage
	# the camera (pan_camera / reset_camera) and cinematic_mode itself; exit
	# early and let it take over.
	if _main.is_cinematic_playing():
		_room_loading = false
		return

	# Phase 3 — slide the camera in from the opposite direction.
	if cam != null:
		cam.position_smoothing_enabled = false
		cam.limit_left = -GameConfig.UNLIMITED_CAMERA_LIMIT
		cam.limit_top = -GameConfig.UNLIMITED_CAMERA_LIMIT
		cam.limit_right = GameConfig.UNLIMITED_CAMERA_LIMIT
		cam.limit_bottom = GameConfig.UNLIMITED_CAMERA_LIMIT
		cam.offset = -slide_vec
		var tween_in: Tween = cam.create_tween()
		tween_in.tween_property(cam, "offset", Vector2.ZERO, TRANSITION_DURATION) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween_in.finished
		cam.position_smoothing_enabled = true
		_player.set_camera_limits(current_room.get_room_rect())

	_room_loading = false
	_player.cinematic_mode = false


## Returns the camera offset vector used for the slide-out and slide-in phases.
## Slides by one viewport-width (H) or viewport-height (V) in world units so the
## old room fully leaves the screen before the new one arrives.
func _get_transition_vector(direction: String) -> Vector2:
	match direction:
		"east":  return Vector2(TRANSITION_SLIDE_H, 0.0)
		"west":  return Vector2(-TRANSITION_SLIDE_H, 0.0)
		"south": return Vector2(0.0, TRANSITION_SLIDE_V)
		"north": return Vector2(0.0, -TRANSITION_SLIDE_V)
	return Vector2.ZERO


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
