extends GutTest
## Unit tests for CombatUtils — validates knockback decay and damage flash
## helpers in isolation, without needing a running scene tree.


# ---------------------------------------------------------------------------
# decay_knockback
# ---------------------------------------------------------------------------

func test_decay_knockback_reduces_magnitude() -> void:
	var v := Vector2(400.0, 0.0)
	var result := CombatUtils.decay_knockback(v, 400.0, 0.016, 6.0)
	assert_lt(result.length(), v.length(),
		"decay_knockback should reduce velocity magnitude each frame")


func test_decay_knockback_approaches_zero() -> void:
	var v := Vector2(400.0, 0.0)
	# Run many frames until velocity is negligible.
	for _i: int in range(200):
		v = CombatUtils.decay_knockback(v, 400.0, 0.016, 6.0)
	assert_almost_eq(v.length(), 0.0, 1.0,
		"decay_knockback should drive velocity to near-zero over time")


func test_decay_knockback_zero_input_stays_zero() -> void:
	var result := CombatUtils.decay_knockback(Vector2.ZERO, 400.0, 0.016, 6.0)
	assert_eq(result, Vector2.ZERO,
		"decay_knockback on a zero vector should return zero")


func test_decay_knockback_preserves_direction() -> void:
	var v := Vector2(300.0, 400.0)
	var result := CombatUtils.decay_knockback(v, 500.0, 0.016, 6.0)
	# Direction (normalised) should be unchanged after partial decay.
	assert_almost_eq(result.normalized().x, v.normalized().x, 0.001,
		"decay_knockback should not change the direction of the velocity")
	assert_almost_eq(result.normalized().y, v.normalized().y, 0.001,
		"decay_knockback should not change the direction of the velocity")


func test_decay_knockback_higher_decay_rate_decays_faster() -> void:
	var v_slow := CombatUtils.decay_knockback(Vector2(400.0, 0.0), 400.0, 0.016, 3.0)
	var v_fast := CombatUtils.decay_knockback(Vector2(400.0, 0.0), 400.0, 0.016, 9.0)
	assert_lt(v_fast.length(), v_slow.length(),
		"A higher decay rate should result in a smaller velocity after one frame")


# ---------------------------------------------------------------------------
# flash_damage — visual effect; we only test side-effect on sprite.color
# ---------------------------------------------------------------------------

func test_flash_damage_sets_sprite_to_flash_color() -> void:
	var sprite := ColorRect.new()
	add_child_autoqfree(sprite)
	sprite.color = Color.WHITE
	CombatUtils.flash_damage(sprite, Color.RED, Color.WHITE)
	assert_eq(sprite.color, Color.RED,
		"flash_damage should immediately set sprite color to the flash color")


func test_flash_damage_custom_flash_color() -> void:
	var sprite := ColorRect.new()
	add_child_autoqfree(sprite)
	var flash := Color(1.0, 0.2, 0.2)
	CombatUtils.flash_damage(sprite, flash, Color.BLUE)
	assert_eq(sprite.color, flash,
		"flash_damage should use the supplied flash_color")
