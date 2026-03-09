extends Node
## Manages room lifecycle: loading, saving/restoring state across transitions,
## exit-triggered navigation, and per-room A* pathfinder construction.

const _PATHFINDER_SCRIPT: Script = preload("res://scripts/pathfinder.gd")

var current_room_name: String = ""
# Untyped to allow calling room.gd helper APIs.
var current_room = null
# Persists room state (surviving NPC positions/HP) across room transitions.
var _room_states: Dictionary = {}
## Guards against re-entrant _on_exit_triggered calls during the one-frame
## await in load_room.
var _room_loading: bool = false
## A* pathfinder for the current room; rebuilt each time a room loads.
var _current_pathfinder = null

# ---- External references set by setup() ----
var _room_holder: Node2D = null
var _player = null
# The full LEVELS dictionary from main.gd (passed by reference).
var _levels: Dictionary = {}
# Callable: () -> String — returns current_level_name from main.
var _get_level_name: Callable
# Callable: (npc) — wires up this NPC's signals into dialog/level managers.
var _setup_npc: Callable
# Callable: (room_name) — post-load hook (HUD update, room intros, etc.).
var _on_room_post_load: Callable
# Callable: (direction, key_id) — locked exit notification.
var _on_locked_exit: Callable


func setup(
		p_room_holder: Node2D,
		p_player: Node,
		p_levels: Dictionary,
		p_get_level_name: Callable,
		p_setup_npc: Callable,
		p_on_room_post_load: Callable,
		p_on_locked_exit: Callable) -> void:
	_room_holder = p_room_holder
	_player = p_player
	_levels = p_levels
	_get_level_name = p_get_level_name
	_setup_npc = p_setup_npc
	_on_room_post_load = p_on_room_post_load
	_on_locked_exit = p_on_locked_exit


func load_room(room_name: String, player_pos: Vector2) -> void:
	_room_loading = true
	if current_room:
		_save_room_state()
		# Disconnect the old room's exit signals first.
		if current_room.exit_triggered.is_connected(_on_exit_triggered):
			current_room.exit_triggered.disconnect(_on_exit_triggered)
		if current_room.locked_exit_attempted.is_connected(_on_locked_exit_attempted):
			current_room.locked_exit_attempted.disconnect(_on_locked_exit_attempted)
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
	var level_name: String = _get_level_name.call()
	var level_rooms: Dictionary = _levels[level_name]["rooms"]
	current_room = level_rooms[room_name].instantiate()
	_room_holder.add_child(current_room)
	current_room.exit_triggered.connect(_on_exit_triggered)
	current_room.locked_exit_attempted.connect(_on_locked_exit_attempted)

	# Connect level-end triggers.
	for trigger in get_tree().get_nodes_in_group("level_end"):
		if trigger.has_signal("level_end_reached") and not trigger.has_meta("_duddy_level_end_connected"):
			trigger.level_end_reached.connect(_on_level_end_reached_forward.bind(trigger))
			trigger.set_meta("_duddy_level_end_connected", true)

	# Restore saved state before connecting any signals so we never wire up
	# nodes about to be freed.
	_restore_room_state(room_name)

	# Give NPCs a reference to the player; wire up interaction signals.
	for npc in current_room.get_npcs():
		if npc.is_queued_for_deletion():
			continue
		if npc.has_method("set_player_reference"):
			npc.set_player_reference(_player)
		_setup_npc.call(npc)

	_player.set_camera_limits(current_room.get_room_rect())

	# Connect the bedroom door hint signal.
	if room_name == "l1_bedroom":
		var door: Node = current_room.get_node_or_null("MagicDoor")
		if door != null and door.has_signal("door_approached"):
			door.door_approached.connect(_on_bedroom_door_approached_forward)

	# Keep transition guard active for one additional physics frame after the
	# new room is instantiated.
	await get_tree().physics_frame
	_room_loading = false

	# Build the A* pathfinder now that all physics bodies are registered.
	_rebuild_pathfinder()

	# Notify main of post-load actions (HUD update, room intros).
	_on_room_post_load.call(room_name)


## Snapshot the current room's NPC, item, and switch states before transitioning away.
func _save_room_state() -> void:
	if current_room == null or current_room_name == "":
		return
	var npc_states: Dictionary = {}
	for npc in current_room.get_npcs():
		if npc.is_queued_for_deletion():
			continue
		npc_states[npc.name] = {
			"position": npc.global_position,
			"hp": npc.hp,
		}
	var item_names: Array[String] = []
	for item in current_room.get_items():
		if not item.is_queued_for_deletion():
			item_names.append(item.name)
	var switch_states: Dictionary = {}
	for sw in current_room.get_switches():
		switch_states[sw.name] = sw.is_on
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
	if "npcs" in state:
		var npc_states: Dictionary = state["npcs"]
		for npc in current_room.get_npcs():
			if npc.name not in npc_states:
				npc.queue_free()
			else:
				var npc_data: Dictionary = npc_states[npc.name]
				npc.global_position = npc_data["position"]
				npc.hp = npc_data["hp"]
	if "items" in state:
		var present_items: Array[String] = state["items"]
		for item in current_room.get_items():
			if item.name not in present_items:
				item.queue_free()
	if "switches" in state:
		var switch_states: Dictionary = state["switches"]
		for sw in current_room.get_switches():
			if sw.name in switch_states and sw.is_on != switch_states[sw.name]:
				sw.on_hit()
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
	if _room_loading:
		return
	var level_name: String = _get_level_name.call()
	if current_room_name not in _levels[level_name]["connections"]:
		return
	var connections: Dictionary = _levels[level_name]["connections"][current_room_name]
	if direction not in connections:
		return
	var next: Dictionary = connections[direction]
	load_room(next["room"], next["entry"])


func _on_locked_exit_attempted(direction: String, key_id: String) -> void:
	_on_locked_exit.call(direction, key_id)


## Forwarding slot for level-end trigger signal (routed through main to level_manager).
## Stored as a Callable so it can be overridden by main after setup.
var _on_level_end_reached_cb: Callable

func _on_level_end_reached_forward(trigger: Node) -> void:
	if _on_level_end_reached_cb.is_valid():
		_on_level_end_reached_cb.call(trigger)


## Forwarding slot for the bedroom door-approached signal.
## Stored as a Callable so it can be set by main after setup.
var _on_bedroom_door_approached_cb: Callable

func _on_bedroom_door_approached_forward() -> void:
	if _on_bedroom_door_approached_cb.is_valid():
		_on_bedroom_door_approached_cb.call()


## Public helper: load a room by name and entry position.
func trigger_exit(direction: String) -> void:
	_on_exit_triggered(direction)


## Public getter for the current room's A* pathfinder (may be null).
func get_pathfinder() -> Variant:
	return _current_pathfinder


## Builds an A* pathfinder for the current room if any NPC uses A*.
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
	if not current_room.is_inside_tree():
		return
	var pathfinder = _PATHFINDER_SCRIPT.new()
	pathfinder.build(current_room.get_world_2d().direct_space_state, current_room.global_position)
	_current_pathfinder = pathfinder
	for npc: Node in current_room.get_npcs():
		if npc.get("use_astar") and npc.has_method("set_pathfinder"):
			npc.set_pathfinder(_current_pathfinder)
