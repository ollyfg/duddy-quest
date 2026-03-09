extends GutTest
## Unit tests for DialogManager._pick_npc_dialog() — verifies dialog
## selection logic using lightweight mock player/NPC objects.


## Minimal player stand-in: only the inventory and has_key() API are needed.
class MockPlayer extends Node:
	var inventory: Array[String] = []
	func has_key(key_id: String) -> bool:
		return key_id in inventory


## Minimal NPC stand-in exposing the same exported properties that
## _pick_npc_dialog() reads.
class MockNpc extends Node:
	var requires_key_id: String = ""
	var key_accept_dialog: Array = []
	var after_key_id: String = ""
	var after_key_dialog: Array = []
	var requires_item: String = ""
	var requires_item_dialog: Array = []
	var gives_key_id: String = ""
	var gives_key_flag: String = ""
	var requires_flag: String = ""
	var pre_flag_dialog: Array = []
	var dialog_pools: Array = []
	var dialog_lines: Array = ["Hello!"]
	var dialog_suffix: Array = []


var _dm: Node
var _player: MockPlayer
var _npc: MockNpc


func before_each() -> void:
	_player = MockPlayer.new()
	add_child_autoqfree(_player)

	_npc = MockNpc.new()
	add_child_autoqfree(_npc)

	_dm = Node.new()
	_dm.set_script(preload("res://scripts/dialog_manager.gd"))
	add_child_autoqfree(_dm)
	# Wire the mock player directly; avoids the dialog_box/main dependencies.
	_dm._player = _player


func after_each() -> void:
	# Erase any flags set during a test so they do not bleed into the next.
	GameState.flags.clear()


# ---------------------------------------------------------------------------
# Fallback path (no gates configured)
# ---------------------------------------------------------------------------

func test_fallback_returns_dialog_lines() -> void:
	_npc.dialog_lines = ["Hi there!"]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Hi there!"],
		"With no gates set, _pick_npc_dialog should return dialog_lines")


func test_fallback_appends_dialog_suffix() -> void:
	_npc.dialog_lines = ["Line 1"]
	_npc.dialog_suffix = ["Goodbye"]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Line 1", "Goodbye"],
		"_pick_npc_dialog should append dialog_suffix to dialog_lines")


# ---------------------------------------------------------------------------
# requires_key_id gate
# ---------------------------------------------------------------------------

func test_requires_key_returns_key_accept_dialog_when_player_has_key() -> void:
	_npc.requires_key_id = "golden_key"
	_npc.key_accept_dialog = ["Thank you for the key!"]
	_player.inventory = ["golden_key"]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Thank you for the key!"],
		"When player has required key, key_accept_dialog should be returned")


func test_requires_key_falls_back_to_dialog_lines_when_accept_dialog_empty() -> void:
	_npc.requires_key_id = "golden_key"
	_npc.key_accept_dialog = []
	_npc.dialog_lines = ["Default."]
	_player.inventory = ["golden_key"]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Default."],
		"Empty key_accept_dialog falls back to dialog_lines")


func test_requires_key_skips_gate_when_player_lacks_key() -> void:
	_npc.requires_key_id = "golden_key"
	_npc.key_accept_dialog = ["Thank you!"]
	_npc.dialog_lines = ["Bring me the golden key."]
	_player.inventory = []
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Bring me the golden key."],
		"When player lacks required key, fallback dialog_lines is returned")


# ---------------------------------------------------------------------------
# after_key_id gate
# ---------------------------------------------------------------------------

func test_after_key_returns_after_key_dialog_when_player_has_key() -> void:
	_npc.after_key_id = "silver_key"
	_npc.after_key_dialog = ["You already found it!"]
	_player.inventory = ["silver_key"]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["You already found it!"],
		"When player has after_key_id, after_key_dialog should be returned")


func test_after_key_falls_back_to_dialog_lines_when_after_dialog_empty() -> void:
	_npc.after_key_id = "silver_key"
	_npc.after_key_dialog = []
	_npc.dialog_lines = ["Default fallback."]
	_player.inventory = ["silver_key"]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Default fallback."],
		"Empty after_key_dialog falls back to dialog_lines")


func test_after_key_skips_gate_when_player_lacks_key() -> void:
	_npc.after_key_id = "silver_key"
	_npc.after_key_dialog = ["You found it!"]
	_npc.dialog_lines = ["Go find the silver key."]
	_player.inventory = []
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Go find the silver key."],
		"When player lacks after_key_id, normal dialog_lines is returned")


# ---------------------------------------------------------------------------
# requires_item gate (new gate type — only dialog_manager.gd changes needed)
# ---------------------------------------------------------------------------

func test_requires_item_returns_hint_dialog_when_player_lacks_item() -> void:
	_npc.requires_item = "torch"
	_npc.requires_item_dialog = ["You need a torch to enter."]
	_npc.dialog_lines = ["Welcome!"]
	_player.inventory = []
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["You need a torch to enter."],
		"When player lacks requires_item, requires_item_dialog should be shown")


func test_requires_item_falls_back_to_ellipsis_when_hint_dialog_empty() -> void:
	_npc.requires_item = "torch"
	_npc.requires_item_dialog = []
	_npc.dialog_lines = ["Welcome!"]
	_player.inventory = []
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["..."],
		"Empty requires_item_dialog falls back to ['...']")


func test_requires_item_allows_dialog_when_player_has_item() -> void:
	_npc.requires_item = "torch"
	_npc.requires_item_dialog = ["You need a torch."]
	_npc.dialog_lines = ["Welcome, adventurer!"]
	_player.inventory = ["torch"]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Welcome, adventurer!"],
		"When player has requires_item, normal dialog_lines should be returned")


func test_requires_item_does_not_consume_item() -> void:
	_npc.requires_item = "map"
	_npc.dialog_lines = ["Good, you have the map."]
	_player.inventory = ["map"]
	_dm._pick_npc_dialog(_npc)
	assert_true("map" in _player.inventory,
		"requires_item should not consume the item from inventory")


# ---------------------------------------------------------------------------
# Flag gate (requires_flag / pre_flag_dialog)
# ---------------------------------------------------------------------------

func test_requires_flag_returns_pre_flag_dialog_when_flag_not_set() -> void:
	_npc.requires_flag = "l1_hallway_intro_shown"
	_npc.pre_flag_dialog = ["Not yet..."]
	_npc.dialog_lines = ["Come in!"]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Not yet..."],
		"When flag gate is not met, pre_flag_dialog should be returned")


func test_requires_flag_returns_dialog_lines_when_flag_set() -> void:
	GameState.flags["l1_hallway_intro_shown"] = true
	_npc.requires_flag = "l1_hallway_intro_shown"
	_npc.pre_flag_dialog = ["Not yet..."]
	_npc.dialog_lines = ["Come in!"]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Come in!"],
		"When flag gate is met, dialog_lines should be returned")


func test_requires_flag_returns_ellipsis_when_pre_flag_dialog_empty() -> void:
	_npc.requires_flag = "l1_hallway_intro_shown"
	_npc.pre_flag_dialog = []
	_npc.dialog_lines = ["Come in!"]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["..."],
		"Empty pre_flag_dialog falls back to ['...']")


# ---------------------------------------------------------------------------
# Gate priority: requires_item is evaluated before flag gate
# ---------------------------------------------------------------------------

func test_requires_item_checked_before_flag_gate() -> void:
	_npc.requires_item = "torch"
	_npc.requires_item_dialog = ["Need a torch."]
	_npc.requires_flag = "l1_hallway_intro_shown"
	_npc.pre_flag_dialog = ["Flag not set."]
	_npc.dialog_lines = ["All good."]
	_player.inventory = []
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Need a torch."],
		"requires_item gate should be evaluated before flag gate")


func test_requires_item_passes_to_flag_gate_when_item_present() -> void:
	_npc.requires_item = "torch"
	_npc.requires_item_dialog = ["Need a torch."]
	_npc.requires_flag = "l1_hallway_intro_shown"
	_npc.pre_flag_dialog = ["Flag not set."]
	_npc.dialog_lines = ["All good."]
	_player.inventory = ["torch"]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Flag not set."],
		"When requires_item passes, flag gate should still be evaluated")


# ---------------------------------------------------------------------------
# Dialog pools
# ---------------------------------------------------------------------------

func test_dialog_pools_result_starts_with_dialog_lines() -> void:
	_npc.dialog_lines = ["Hello!"]
	_npc.dialog_pools = [["Pool line A"], ["Pool line B"]]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result[0], "Hello!",
		"Result with dialog_pools should start with dialog_lines")


func test_dialog_pools_result_includes_a_pool() -> void:
	_npc.dialog_lines = ["Hello!"]
	_npc.dialog_pools = [["Pool line."]]
	var result: Array = _dm._pick_npc_dialog(_npc)
	assert_eq(result, ["Hello!", "Pool line."],
		"Result with a single pool should append that pool to dialog_lines")
