extends Node
## Manages NPC dialog interactions, post-dialog side effects, and dialog-gate
## state (pausing NPCs while dialog is open).

## Action to run when dialog closes (used for player catch/kickback flows).
enum PostDialogAction { NONE, GO_WEST, PETUNIA_KICK }

var _post_dialog_action: int = PostDialogAction.NONE
## Tracks the NPC whose dialog is currently active so post-dialog actions
## (giving keys, accepting keys, setting flags) can be applied on close.
var _interacting_npc: Node = null

var _dialog_box = null
var _player = null
# Callable: () -> Node  — returns current_room from main/room_manager.
var _get_current_room: Callable
# Callable: (sequence, on_finish) — delegates to level_manager.play_cinematic.
var _play_cinematic: Callable
# Callable: (direction) — delegates to room_manager._on_exit_triggered.
var _on_exit_triggered: Callable


func setup(
		p_dialog_box: Node,
		p_player: Node,
		p_get_current_room: Callable,
		p_play_cinematic: Callable,
		p_on_exit_triggered: Callable) -> void:
	_dialog_box = p_dialog_box
	_player = p_player
	_get_current_room = p_get_current_room
	_play_cinematic = p_play_cinematic
	_on_exit_triggered = p_on_exit_triggered


func on_npc_interaction_requested(npc) -> void:  ## npc: CharacterBody2D (untyped for test-double compatibility)
	if _dialog_box.is_active():
		return
	_interacting_npc = npc
	set_dialog_active(true)
	_dialog_box.set_speaker(npc.npc_name)
	_dialog_box.start_dialog(_pick_npc_dialog(npc))


## Choose the correct dialog lines for an NPC, respecting flag gates and
## key-requirement states.
## npc: CharacterBody2D (untyped for test-double compatibility)
func _pick_npc_dialog(npc) -> Array:
	# Key-accepting NPC and the player already carries the required key.
	if npc.requires_key_id != "" and _player.has_key(npc.requires_key_id):
		return npc.key_accept_dialog if not npc.key_accept_dialog.is_empty() else npc.dialog_lines

	# NPC with after_key_dialog: switch to short lines once the player has
	# already found the associated key item.
	if npc.after_key_id != "" and _player.has_key(npc.after_key_id):
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
## Shows the NPC's detection line as a warning.
func on_npc_player_detected(dialog: String) -> void:
	if _dialog_box.is_active() or _post_dialog_action != PostDialogAction.NONE:
		return
	set_dialog_active(true)
	_dialog_box.set_speaker("")
	_dialog_box.start_dialog([dialog])


func on_bedroom_door_approached() -> void:
	if GameState.has_flag("l1_bedroom_door_hint_shown") or _dialog_box.is_active():
		return
	GameState.set_flag("l1_bedroom_door_hint_shown")
	set_dialog_active(true)
	_dialog_box.set_speaker("")
	_dialog_box.start_dialog([
		"You try to open the door but it's locked.",
		"Maybe if you whack it enough...",
	])


## Called when Petunia's HitArea physically contacts the player.
## Shows her catch line then plays a cinematic marching the player back.
func on_petunia_hit_player() -> void:
	if _player.cinematic_mode or _dialog_box.is_active() or _post_dialog_action != PostDialogAction.NONE:
		return
	_post_dialog_action = PostDialogAction.PETUNIA_KICK
	set_dialog_active(true)
	_dialog_box.set_speaker("Petunia")
	var catch_phrases: Array = [
		"Back to your room, DUDDIKINS!",
		"Oh NO you don't, young man! BACK!",
		"Dudley Dursley! Where do you think YOU'RE going?!",
		"NOT one more step! Your father will hear about this!",
		"You'll spoil your APPETITE! GET BACK HERE!",
		"DUDLEY VERNON DURSLEY! Turn around THIS INSTANT!",
		"Not another step, young man! I have EYES in the back of my head!",
		"Ohhh no no no. Not today. Back inside. NOW.",
		"This is NOT how we behave in this family! UPSTAIRS!",
		"I did NOT raise you to go gallivanting about! INSIDE!",
	]
	_dialog_box.start_dialog([catch_phrases.pick_random()])


func on_dialog_ended() -> void:
	set_dialog_active(false)
	var action: int = _post_dialog_action
	_post_dialog_action = PostDialogAction.NONE

	# A "go_west" post-dialog action takes priority (Petunia sending player back).
	if action == PostDialogAction.GO_WEST:
		_interacting_npc = null
		_on_exit_triggered.call("west")
		return

	# Petunia catches the player: cinematic marching them back to the bedroom door.
	if action == PostDialogAction.PETUNIA_KICK:
		_interacting_npc = null
		# Return Petunia (and any other cinematic_kick_back NPC) to her patrol
		# route immediately so she doesn't continue chasing during the escort.
		if is_instance_valid(_player):
			for npc: Node in _player.get_tree().get_nodes_in_group("cinematic_kick_back"):
				if npc.has_method("reset_patrol"):
					npc.reset_patrol()
		var kick_origin: Vector2 = _player.global_position
		_play_cinematic.call([
			{"type": "move_player", "to": Vector2(kick_origin.x, 320.0), "speed": 100.0},
			{"type": "move_player", "to": Vector2(64.0, 320.0), "speed": 100.0},
		], func():
			_on_exit_triggered.call("west")
		)
		return

	# Apply any post-interaction effects for the NPC whose dialog just ended.
	var npc: Node = _interacting_npc
	_interacting_npc = null
	if npc != null and is_instance_valid(npc):
		_handle_post_npc_dialog(npc)


## Apply post-dialog effects: give keys, accept keys, set game flags.
func _handle_post_npc_dialog(npc: Node) -> void:
	# NPC requires a key the player has → accept it and remove the NPC.
	if npc.requires_key_id != "" and _player.has_key(npc.requires_key_id):
		_player.remove_key(npc.requires_key_id)
		npc.queue_free()
		return

	# NPC gives a key when its flag gate is satisfied → give key and remove NPC.
	if npc.gives_key_id != "":
		var flag: String = npc.gives_key_flag
		if flag == "" or GameState.has_flag(flag):
			_player.inventory.append(npc.gives_key_id)
			_player.keys_changed.emit(_player.inventory.size())
			npc.queue_free()
			return

	# Normal interaction: set a game flag if configured.
	if npc.sets_game_flag != "":
		GameState.set_flag(npc.sets_game_flag)


func set_dialog_active(active: bool) -> void:
	_player.is_in_dialog = active
	var current_room: Node = _get_current_room.call()
	if current_room:
		# Keep NPCs paused during an active cinematic; only fully unpause when
		# both dialog ends AND no cinematic is playing.
		var should_pause: bool = active or _player.cinematic_mode
		for npc in current_room.get_npcs():
			npc.is_paused = should_pause
