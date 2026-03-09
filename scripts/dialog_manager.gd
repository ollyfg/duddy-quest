extends Node
## Manages all dialog interactions: NPC conversations, post-dialog effects,
## detection lines, locked-exit messages, and the Petunia kick-back cinematic.

enum PostDialogAction { NONE, GO_WEST, PETUNIA_KICK }

## Untyped to allow accessing player.gd custom signals and properties.
var _player
## Untyped to allow calling dialog_box.gd methods (is_active, start_dialog).
var _dialog_box
## Reference to main.gd for play_cinematic and cross-manager access.
var _main: Node

## Untyped to allow accessing npc.gd properties after validity check.
var _interacting_npc = null
var _post_dialog_action: int = PostDialogAction.NONE


func setup(player, dialog_box, main: Node) -> void:
	_player = player
	_dialog_box = dialog_box
	_main = main
	dialog_box.dialog_ended.connect(_on_dialog_ended)


func on_npc_interaction_requested(npc: Node) -> void:
	if _dialog_box.is_active():
		return
	_interacting_npc = npc
	set_dialog_active(true)
	_dialog_box.set_speaker(npc.npc_name)
	_dialog_box.start_dialog(_pick_npc_dialog(npc))


## Choose the correct dialog lines for an NPC, respecting flag gates and
## key-requirement states.
func _pick_npc_dialog(npc: Node) -> Array:
	# Key-accepting NPC and the player already carries the required key.
	if npc.requires_key_id != "" and _player.has_key(npc.requires_key_id):
		return npc.key_accept_dialog if not npc.key_accept_dialog.is_empty() else npc.dialog_lines

	# NPC with after_key_dialog: switch to meow/short lines once the player
	# has already found the associated key item.
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
## Shows her catch line then triggers the kick-back cinematic.
func on_petunia_hit_player() -> void:
	var room_manager: Node = _main.room_manager
	if room_manager.is_loading() or _player.cinematic_mode or _dialog_box.is_active() or _post_dialog_action != PostDialogAction.NONE:
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


func _on_dialog_ended() -> void:
	set_dialog_active(false)
	var action: int = _post_dialog_action
	_post_dialog_action = PostDialogAction.NONE

	# A "go_west" post-dialog action takes priority (Petunia sending player back).
	if action == PostDialogAction.GO_WEST:
		_interacting_npc = null
		_main.room_manager.trigger_exit("west")
		return

	# Petunia catches the player: cinematic marching them back to the bedroom door.
	if action == PostDialogAction.PETUNIA_KICK:
		_interacting_npc = null
		# Return Petunia (and any other cinematic_kick_back NPC) to her patrol
		# route immediately so she doesn't continue chasing during the escort.
		for npc: Node in get_tree().get_nodes_in_group("cinematic_kick_back"):
			if npc.has_method("reset_patrol"):
				npc.reset_patrol()
		var kick_origin: Vector2 = _player.global_position
		_main.play_cinematic([
			{"type": "move_player", "to": Vector2(kick_origin.x, 320.0), "speed": 100.0},
			{"type": "move_player", "to": Vector2(64.0, 320.0), "speed": 100.0},
		], func():
			_main.room_manager.trigger_exit("west")
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
	var room_manager: Node = _main.room_manager
	if room_manager.current_room:
		# Keep NPCs paused during an active cinematic; only fully unpause when
		# both dialog ends AND no cinematic is playing.
		var should_pause: bool = active or _player.cinematic_mode
		for npc in room_manager.current_room.get_npcs():
			npc.is_paused = should_pause


func on_locked_exit_attempted(_direction: String, _key_id: String) -> void:
	if not _dialog_box.is_active():
		set_dialog_active(true)
		_dialog_box.set_speaker("")
		_dialog_box.start_dialog(["It's locked."])
