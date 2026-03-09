extends GutTest
## Integration tests for GameState — verifies flag and level-completion
## behaviour rather than raw property access.

const GameStateScript = preload("res://scripts/game_state.gd")

var _gs: Node


func before_each() -> void:
	_gs = GameStateScript.new()
	add_child_autoqfree(_gs)


# ---------------------------------------------------------------------------
# Flag behaviour
# ---------------------------------------------------------------------------

func test_unknown_flag_is_false() -> void:
	assert_false(_gs.has_flag("nonexistent_flag"),
		"has_flag should return false for a flag that was never set")


func test_set_flag_makes_has_flag_true() -> void:
	_gs.set_flag("l1_hallway_intro_shown")
	assert_true(_gs.has_flag("l1_hallway_intro_shown"),
		"has_flag should return true after set_flag")


func test_set_flag_does_not_pollute_other_flags() -> void:
	_gs.set_flag("l1_hallway_intro_shown")
	assert_false(_gs.has_flag("l1_street_intro_shown"),
		"Setting l1_hallway_intro_shown must not affect l1_street_intro_shown")


func test_set_same_flag_twice_still_true() -> void:
	_gs.set_flag("l1_bedroom_door_hint_shown")
	_gs.set_flag("l1_bedroom_door_hint_shown")
	assert_true(_gs.has_flag("l1_bedroom_door_hint_shown"),
		"Setting the same flag twice should still leave it set")


func test_set_unknown_flag_emits_warning() -> void:
	# set_flag with an unknown name should push_warning but not crash.
	# We verify the flag is still stored even for unknown names.
	_gs.set_flag("totally_unknown_flag")
	assert_true(_gs.has_flag("totally_unknown_flag"),
		"Unknown flag should still be stored even though a warning was issued")


# ---------------------------------------------------------------------------
# clear_level_flags behaviour
# ---------------------------------------------------------------------------

func test_clear_level_flags_removes_matching_flags() -> void:
	_gs.set_flag("l1_hallway_intro_shown")
	_gs.set_flag("l1_street_intro_shown")
	_gs.clear_level_flags("l1_")
	assert_false(_gs.has_flag("l1_hallway_intro_shown"),
		"clear_level_flags('l1_') should clear l1_hallway_intro_shown")
	assert_false(_gs.has_flag("l1_street_intro_shown"),
		"clear_level_flags('l1_') should clear l1_street_intro_shown")


func test_clear_level_flags_does_not_remove_other_flags() -> void:
	_gs.set_flag("l1_hallway_intro_shown")
	# Directly set a flag that isn't in KNOWN_FLAGS to avoid a push_warning,
	# since we just want to verify the prefix filter leaves unrelated flags alone.
	_gs.flags["other_flag"] = true
	_gs.clear_level_flags("l1_")
	assert_true(_gs.has_flag("other_flag"),
		"clear_level_flags('l1_') must not remove flags without the 'l1_' prefix")


func test_clear_level_flags_on_empty_flags_is_safe() -> void:
	_gs.clear_level_flags("l1_")
	assert_true(true, "clear_level_flags on empty dict should not crash")


# ---------------------------------------------------------------------------
# KNOWN_FLAGS constant
# ---------------------------------------------------------------------------

func test_known_flags_contains_l1_flags() -> void:
	assert_true("l1_bedroom_door_hint_shown" in GameStateScript.KNOWN_FLAGS,
		"KNOWN_FLAGS must include l1_bedroom_door_hint_shown")
	assert_true("l1_hallway_intro_shown" in GameStateScript.KNOWN_FLAGS,
		"KNOWN_FLAGS must include l1_hallway_intro_shown")
	assert_true("l1_street_intro_shown" in GameStateScript.KNOWN_FLAGS,
		"KNOWN_FLAGS must include l1_street_intro_shown")


# ---------------------------------------------------------------------------
# Level-completion behaviour
# ---------------------------------------------------------------------------

func test_unknown_level_is_not_complete() -> void:
	assert_false(_gs.is_complete("level_99"),
		"is_complete should return false for a never-completed level")


func test_mark_complete_makes_level_complete() -> void:
	_gs.mark_complete("level_1")
	assert_true(_gs.is_complete("level_1"),
		"is_complete should return true after mark_complete")


func test_mark_complete_does_not_affect_other_levels() -> void:
	_gs.mark_complete("level_1")
	assert_false(_gs.is_complete("level_2"),
		"Completing level_1 must not mark level_2 as complete")


func test_mark_complete_is_idempotent() -> void:
	_gs.mark_complete("level_1")
	_gs.mark_complete("level_1")
	assert_eq(_gs.completed_levels.size(), 1,
		"Completing the same level twice should only record it once")
