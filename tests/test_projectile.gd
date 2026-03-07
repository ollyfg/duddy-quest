extends GutTest
## Integration tests for Projectile — verifies setup, reflect and direction
## behaviour using the real projectile scene.

const ProjectileScene = preload("res://scenes/projectile.tscn")

var _proj: CharacterBody2D


func before_each() -> void:
	_proj = ProjectileScene.instantiate()
	add_child_autoqfree(_proj)


# ---------------------------------------------------------------------------
# Setup behaviour
# ---------------------------------------------------------------------------

func test_setup_sets_direction() -> void:
	_proj.setup(Vector2.RIGHT, false)
	assert_eq(_proj.direction, Vector2.RIGHT,
		"setup should store the given direction")


func test_setup_normalises_direction() -> void:
	_proj.setup(Vector2(3.0, 4.0), false)
	assert_almost_eq(_proj.direction.length(), 1.0, 0.001,
		"setup should normalise the direction vector")


func test_setup_marks_player_projectile() -> void:
	_proj.setup(Vector2.UP, false)
	assert_false(_proj.is_enemy_projectile,
		"setup(dir, false) should mark this as a player projectile")


func test_setup_marks_enemy_projectile() -> void:
	_proj.setup(Vector2.UP, true)
	assert_true(_proj.is_enemy_projectile,
		"setup(dir, true) should mark this as an enemy projectile")


# ---------------------------------------------------------------------------
# Reflect behaviour
# ---------------------------------------------------------------------------

func test_reflect_reverses_direction() -> void:
	_proj.setup(Vector2.RIGHT, true)
	_proj.reflect()
	assert_eq(_proj.direction, Vector2.LEFT,
		"reflect should reverse the projectile direction")


func test_reflect_clears_enemy_flag() -> void:
	_proj.setup(Vector2.RIGHT, true)
	_proj.reflect()
	assert_false(_proj.is_enemy_projectile,
		"reflect should mark the projectile as belonging to the player")


func test_reflect_sets_reflected_flag() -> void:
	_proj.setup(Vector2.RIGHT, true)
	_proj.reflect()
	assert_true(_proj._reflected,
		"reflect should set the _reflected flag to prevent double-reflection")


func test_reflect_can_only_be_applied_once() -> void:
	_proj.setup(Vector2.RIGHT, true)
	_proj.reflect()
	# Second call should be ignored: direction must stay reversed (LEFT).
	_proj.reflect()
	assert_eq(_proj.direction, Vector2.LEFT,
		"A second reflect() call must not change direction again")


func test_unreflected_projectile_has_reflected_false() -> void:
	_proj.setup(Vector2.DOWN, true)
	assert_false(_proj._reflected,
		"A freshly set-up projectile must not be marked as reflected")
