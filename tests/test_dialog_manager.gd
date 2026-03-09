extends GutTest
## Isolated tests for DialogManager — verifies NPC dialog selection logic
## and post-dialog action state machine.

const DialogManagerScript = preload("res://scripts/dialog_manager.gd")


class DummyDialogBox:
	extends Node
	var _active: bool = false
	var _last_lines: Array = []
	var _last_speaker: String = ""

	func is_active() -> bool:
		return _active

	func start_dialog(lines: Array) -> void:
		_active = true
		_last_lines = lines

	func set_speaker(name: String) -> void:
		_last_speaker = name


class DummyPlayer:
	extends Node
	var is_in_dialog: bool = false
	var cinematic_mode: bool = false
	var _keys: Array[String] = []

	func has_key(key_id: String) -> bool:
		return key_id in _keys


class DummyNpc:
	var npc_name: String = ""
	var dialog_lines: Array = ["Hello"]
	var dialog_suffix: Array = []
	var dialog_pools: Array = []
	var pre_flag_dialog: Array = []
	var key_accept_dialog: Array = ["Thank you!"]
	var after_key_dialog: Array = []
	var requires_key_id: String = ""
	var after_key_id: String = ""
	var gives_key_id: String = ""
	var gives_key_flag: String = ""
	var requires_flag: String = ""
	var sets_game_flag: String = ""


func _make_dm() -> Node:
	var dm := DialogManagerScript.new()
	var db := DummyDialogBox.new()
	var p := DummyPlayer.new()
	dm.setup(
		db,
		p,
		func() -> Node: return null,
		func(_seq: Array, _cb: Callable) -> void: pass,
		func(_dir: String) -> void: pass
	)
	return dm


# ---------------------------------------------------------------------------
# _pick_npc_dialog tests
# ---------------------------------------------------------------------------

func test_pick_npc_dialog_returns_base_lines() -> void:
	var dm := _make_dm()
	var npc := DummyNpc.new()
	npc.dialog_lines = ["Line 1", "Line 2"]
	var result: Array = dm._pick_npc_dialog(npc)
	assert_eq(result, ["Line 1", "Line 2"], "Should return npc.dialog_lines when no gates apply")
	dm.free()


func test_pick_npc_dialog_appends_suffix() -> void:
	var dm := _make_dm()
	var npc := DummyNpc.new()
	npc.dialog_lines = ["Hello"]
	npc.dialog_suffix = ["Goodbye"]
	var result: Array = dm._pick_npc_dialog(npc)
	assert_eq(result, ["Hello", "Goodbye"], "Suffix should be appended to dialog lines")
	dm.free()


func test_pick_npc_dialog_returns_key_accept_when_player_has_key() -> void:
	var dm := _make_dm()
	var npc := DummyNpc.new()
	npc.requires_key_id = "key_front_door"
	npc.key_accept_dialog = ["Thank you, I'll unlock it."]
	(dm._player as DummyPlayer)._keys.append("key_front_door")
	var result: Array = dm._pick_npc_dialog(npc)
	assert_eq(result, ["Thank you, I'll unlock it."], "Should return key_accept_dialog when player has the key")
	dm.free()


func test_pick_npc_dialog_returns_pre_flag_when_flag_missing() -> void:
	var dm := _make_dm()
	var npc := DummyNpc.new()
	npc.requires_flag = "some_flag"
	npc.pre_flag_dialog = ["Not yet..."]
	# GameState won't have the flag → should return pre_flag_dialog.
	var result: Array = dm._pick_npc_dialog(npc)
	assert_eq(result, ["Not yet..."], "Should return pre_flag_dialog when gate flag is not set")
	dm.free()


# ---------------------------------------------------------------------------
# post_dialog_action state
# ---------------------------------------------------------------------------

func test_post_dialog_action_defaults_to_none() -> void:
	var dm := _make_dm()
	assert_eq(dm._post_dialog_action, DialogManagerScript.PostDialogAction.NONE,
		"Default post-dialog action should be NONE")
	dm.free()


func test_on_dialog_ended_clears_non_none_action() -> void:
	var dm := _make_dm()
	# Manually inject a GO_WEST action; on_dialog_ended should clear it
	# (GO_WEST with a null _on_exit_triggered callable will be a no-op call).
	dm._post_dialog_action = DialogManagerScript.PostDialogAction.GO_WEST
	dm.on_dialog_ended()
	assert_eq(dm._post_dialog_action, DialogManagerScript.PostDialogAction.NONE,
		"on_dialog_ended should reset _post_dialog_action to NONE")
	dm.free()
