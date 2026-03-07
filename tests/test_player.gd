extends GutTest
## Integration tests for Player — verifies combat, inventory and movement
## cancellation behaviour using the real player scene.

const PlayerScene = preload("res://scenes/player.tscn")

var _player: CharacterBody2D


func before_each() -> void:
	_player = PlayerScene.instantiate()
	add_child_autoqfree(_player)


# ---------------------------------------------------------------------------
# HP / damage behaviour
# ---------------------------------------------------------------------------

func test_player_starts_at_full_hp() -> void:
	assert_eq(_player.hp, _player.MAX_HP,
		"Player should start with MAX_HP health points")


func test_take_damage_reduces_hp() -> void:
	var hp_before: int = _player.hp
	_player.take_damage(1)
	assert_eq(_player.hp, hp_before - 1,
		"take_damage(1) should reduce hp by 1")


func test_take_damage_emits_hp_changed_signal() -> void:
	watch_signals(_player)
	_player.take_damage(1)
	assert_signal_emitted(_player, "hp_changed",
		"hp_changed signal should fire when player takes damage")


func test_hp_cannot_go_below_zero() -> void:
	_player.take_damage(100)
	assert_gte(_player.hp, 0,
		"HP must never drop below 0 regardless of overkill damage")


func test_take_damage_is_blocked_during_invincibility() -> void:
	# First hit starts the invincibility timer.
	_player.take_damage(1)
	var hp_after_first_hit: int = _player.hp
	# Second hit during invincibility window must be ignored.
	_player.take_damage(1)
	assert_eq(_player.hp, hp_after_first_hit,
		"Player should not take damage while invincibility timer is active")


func test_died_signal_emitted_when_hp_reaches_zero() -> void:
	watch_signals(_player)
	_player.take_damage(_player.MAX_HP)
	assert_signal_emitted(_player, "died",
		"died signal should fire when hp reaches 0")


# ---------------------------------------------------------------------------
# Knockback behaviour
# ---------------------------------------------------------------------------

func test_apply_knockback_sets_knockback_velocity() -> void:
	_player.apply_knockback(Vector2.RIGHT)
	assert_gt(_player._knockback_velocity.length(), 0.0,
		"apply_knockback should produce a non-zero knockback velocity")


func test_apply_knockback_direction_is_normalised() -> void:
	_player.apply_knockback(Vector2(3.0, 4.0))
	# The velocity should equal KNOCKBACK_SPEED in that direction.
	assert_almost_eq(
		_player._knockback_velocity.length(),
		_player.KNOCKBACK_SPEED,
		0.01,
		"Knockback velocity magnitude should equal KNOCKBACK_SPEED"
	)


func test_cancel_movement_clears_knockback() -> void:
	_player.apply_knockback(Vector2.RIGHT)
	_player.cancel_movement()
	assert_eq(_player._knockback_velocity, Vector2.ZERO,
		"cancel_movement should zero out knockback velocity")


func test_cancel_movement_stops_grid_step() -> void:
	_player._moving = true
	_player._target_pos = _player.global_position + Vector2(16, 0)
	_player.cancel_movement()
	assert_false(_player._moving,
		"cancel_movement should stop any in-progress grid step")


# ---------------------------------------------------------------------------
# Inventory / wand behaviour
# ---------------------------------------------------------------------------

func test_player_has_no_keys_initially() -> void:
	assert_eq(_player.inventory.size(), 0,
		"Player should start with an empty inventory")


func test_has_key_returns_false_for_missing_key() -> void:
	assert_false(_player.has_key("some_key"),
		"has_key should return false for a key not in inventory")


func test_has_key_returns_true_after_adding_key() -> void:
	_player.inventory.append("door_key")
	assert_true(_player.has_key("door_key"),
		"has_key should return true after key is added to inventory")


func test_remove_key_removes_it_from_inventory() -> void:
	_player.inventory.append("door_key")
	_player.remove_key("door_key")
	assert_false(_player.has_key("door_key"),
		"remove_key should remove the key from inventory")


func test_keys_changed_signal_emitted_on_remove() -> void:
	_player.inventory.append("door_key")
	watch_signals(_player)
	_player.remove_key("door_key")
	assert_signal_emitted(_player, "keys_changed",
		"keys_changed signal should fire after remove_key")


func test_wand_acquired_signal_fires_when_wand_received() -> void:
	watch_signals(_player)
	_player.has_wand = true
	assert_signal_emitted(_player, "wand_acquired",
		"wand_acquired signal should fire when has_wand is set to true")


func test_wand_flag_persists_once_set() -> void:
	_player.has_wand = true
	assert_true(_player.has_wand,
		"has_wand should remain true once set")
