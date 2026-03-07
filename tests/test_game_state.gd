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
	_gs.set_flag("my_flag")
	assert_true(_gs.has_flag("my_flag"),
		"has_flag should return true after set_flag")


func test_set_flag_does_not_pollute_other_flags() -> void:
	_gs.set_flag("flag_a")
	assert_false(_gs.has_flag("flag_b"),
		"Setting flag_a must not affect flag_b")


func test_set_same_flag_twice_still_true() -> void:
	_gs.set_flag("flag_x")
	_gs.set_flag("flag_x")
	assert_true(_gs.has_flag("flag_x"),
		"Setting the same flag twice should still leave it set")


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
