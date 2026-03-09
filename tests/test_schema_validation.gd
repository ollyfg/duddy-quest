extends GutTest
## Unit tests for the schema validation helpers in boss.gd,
## cinematic_player.gd, and dialog_box.gd.
##
## push_error / push_warning tracking is disabled for this file because every
## negative-path test intentionally triggers errors/warnings — that is exactly
## the behaviour we are verifying.

const BossScript = preload("res://scripts/boss.gd")
const CinematicPlayerScript = preload("res://scripts/cinematic_player.gd")
const DialogBoxScene = preload("res://scenes/dialog_box.tscn")


func before_each() -> void:
	# Negative-path tests call push_error/push_warning intentionally;
	# treat them as non-failing so GUT does not mark those tests as failed.
	gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.NOTHING


func after_each() -> void:
	gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.FAILURE


# ---------------------------------------------------------------------------
# boss._validate_phase
# ---------------------------------------------------------------------------

func test_valid_phase_passes_validation() -> void:
	var phase := {
		"hp_threshold": 5,
		"movement_mode": 0,
		"move_speed": 80.0,
	}
	assert_true(BossScript._validate_phase(phase),
		"A phase with hp_threshold should pass validation")


func test_phase_missing_hp_threshold_fails_validation() -> void:
	var phase := {
		"movement_mode": 0,
		"move_speed": 80.0,
	}
	assert_false(BossScript._validate_phase(phase),
		"A phase without hp_threshold should fail validation")


func test_empty_phase_fails_validation() -> void:
	assert_false(BossScript._validate_phase({}),
		"An empty phase dict should fail validation")


# ---------------------------------------------------------------------------
# cinematic_player._validate_step
# ---------------------------------------------------------------------------

func test_known_step_type_passes_validation() -> void:
	var step := {"type": "wait", "duration": 1.0}
	assert_true(CinematicPlayerScript._validate_step(step),
		"A 'wait' step should pass validation")


func test_unknown_step_type_fails_validation() -> void:
	var step := {"type": "typo_step"}
	assert_false(CinematicPlayerScript._validate_step(step),
		"An unknown step type should fail validation")


func test_move_npc_with_required_keys_passes() -> void:
	var step := {"type": "move_npc", "npc": "Harry", "to": Vector2(100, 100)}
	assert_true(CinematicPlayerScript._validate_step(step),
		"A 'move_npc' step with 'npc' and 'to' should pass validation")


func test_move_npc_missing_npc_fails() -> void:
	var step := {"type": "move_npc", "to": Vector2(100, 100)}
	assert_false(CinematicPlayerScript._validate_step(step),
		"A 'move_npc' step missing 'npc' should fail validation")


func test_move_npc_missing_to_fails() -> void:
	var step := {"type": "move_npc", "npc": "Harry"}
	assert_false(CinematicPlayerScript._validate_step(step),
		"A 'move_npc' step missing 'to' should fail validation")


func test_move_player_with_to_passes() -> void:
	var step := {"type": "move_player", "to": Vector2(200, 200)}
	assert_true(CinematicPlayerScript._validate_step(step),
		"A 'move_player' step with 'to' should pass validation")


func test_move_player_missing_to_fails() -> void:
	var step := {"type": "move_player"}
	assert_false(CinematicPlayerScript._validate_step(step),
		"A 'move_player' step missing 'to' should fail validation")


func test_pan_camera_with_to_passes() -> void:
	var step := {"type": "pan_camera", "to": Vector2(300, 300)}
	assert_true(CinematicPlayerScript._validate_step(step),
		"A 'pan_camera' step with 'to' should pass validation")


func test_pan_camera_missing_to_fails() -> void:
	var step := {"type": "pan_camera"}
	assert_false(CinematicPlayerScript._validate_step(step),
		"A 'pan_camera' step missing 'to' should fail validation")


func test_set_visible_with_node_passes() -> void:
	var step := {"type": "set_visible", "node": "SomeNode", "visible": true}
	assert_true(CinematicPlayerScript._validate_step(step),
		"A 'set_visible' step with 'node' should pass validation")


func test_set_visible_missing_node_fails() -> void:
	var step := {"type": "set_visible"}
	assert_false(CinematicPlayerScript._validate_step(step),
		"A 'set_visible' step missing 'node' should fail validation")


func test_dialog_step_passes_without_required_keys() -> void:
	var step := {"type": "dialog", "lines": ["Hello"]}
	assert_true(CinematicPlayerScript._validate_step(step),
		"A 'dialog' step has no required keys and should pass validation")


func test_reset_camera_passes_without_required_keys() -> void:
	var step := {"type": "reset_camera"}
	assert_true(CinematicPlayerScript._validate_step(step),
		"A 'reset_camera' step has no required keys and should pass validation")


func test_empty_type_fails_validation() -> void:
	var step := {"duration": 1.0}
	assert_false(CinematicPlayerScript._validate_step(step),
		"A step with no 'type' key should fail validation")


# ---------------------------------------------------------------------------
# dialog_box._validate_dialog_item
# ---------------------------------------------------------------------------

func test_string_item_passes_validation() -> void:
	var dialog_box = DialogBoxScene.instantiate()
	add_child_autoqfree(dialog_box)
	assert_true(dialog_box._validate_dialog_item("Hello"),
		"A plain String dialog item should pass validation")


func test_dict_with_text_key_passes_validation() -> void:
	var dialog_box = DialogBoxScene.instantiate()
	add_child_autoqfree(dialog_box)
	var item := {"text": "Question?", "options": []}
	assert_true(dialog_box._validate_dialog_item(item),
		"A Dictionary dialog item with 'text' key should pass validation")


func test_dict_missing_text_key_fails_validation() -> void:
	var dialog_box = DialogBoxScene.instantiate()
	add_child_autoqfree(dialog_box)
	var item := {"options": []}
	assert_false(dialog_box._validate_dialog_item(item),
		"A Dictionary dialog item missing 'text' should fail validation")


func test_empty_dict_fails_validation() -> void:
	var dialog_box = DialogBoxScene.instantiate()
	add_child_autoqfree(dialog_box)
	assert_false(dialog_box._validate_dialog_item({}),
		"An empty Dictionary dialog item should fail validation")
