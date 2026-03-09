extends GutTest
## Integration tests for NPC — verifies hostile/friendly behaviour, damage
## handling and invincibility using the real NPC scene.

const NpcScene = preload("res://scenes/npc.tscn")

var _npc: CharacterBody2D


func before_each() -> void:
	_npc = NpcScene.instantiate()
	add_child_autoqfree(_npc)


## Creates an NPC with is_hostile pre-set and adds it to the tree, so _ready()
## runs exactly once with the correct export value.
func _make_npc(hostile: bool) -> CharacterBody2D:
	var npc: CharacterBody2D = NpcScene.instantiate()
	npc.is_hostile = hostile
	add_child_autoqfree(npc)
	return npc


# ---------------------------------------------------------------------------
# Group membership (behaviour, not properties)
# ---------------------------------------------------------------------------

func test_friendly_npc_is_in_npc_group() -> void:
	var npc := _make_npc(false)
	assert_true(npc.is_in_group("npc"),
		"Friendly NPC should be in the 'npc' group")


func test_friendly_npc_is_not_in_enemy_group() -> void:
	var npc := _make_npc(false)
	assert_false(npc.is_in_group("enemy"),
		"Friendly NPC must not be in the 'enemy' group")


func test_hostile_npc_is_in_enemy_group() -> void:
	var npc := _make_npc(true)
	assert_true(npc.is_in_group("enemy"),
		"Hostile NPC should be in the 'enemy' group")


func test_hostile_npc_is_not_in_npc_group() -> void:
	var npc := _make_npc(true)
	assert_false(npc.is_in_group("npc"),
		"Hostile NPC must not be in the 'npc' group")


# ---------------------------------------------------------------------------
# Damage behaviour
# ---------------------------------------------------------------------------

func test_npc_starts_with_full_hp() -> void:
	assert_eq(_npc.hp, _npc.max_hp,
		"NPC should start with max_hp health points")


func test_take_damage_reduces_hp() -> void:
	var hp_before: int = _npc.hp
	_npc.take_damage(1)
	assert_eq(_npc.hp, hp_before - 1,
		"take_damage(1) should reduce NPC hp by 1")


func test_invincible_npc_ignores_damage() -> void:
	_npc.invincible = true
	var hp_before: int = _npc.hp
	_npc.take_damage(1)
	assert_eq(_npc.hp, hp_before,
		"Invincible NPC should not lose HP when take_damage is called")


# ---------------------------------------------------------------------------
# Knockback behaviour
# ---------------------------------------------------------------------------

func test_apply_knockback_sets_velocity() -> void:
	_npc.apply_knockback(Vector2.RIGHT)
	assert_gt(_npc._knockback_velocity.length(), 0.0,
		"apply_knockback should produce a non-zero knockback velocity")


func test_invincible_npc_ignores_knockback() -> void:
	_npc.invincible = true
	_npc.apply_knockback(Vector2.RIGHT)
	assert_eq(_npc._knockback_velocity, Vector2.ZERO,
		"Invincible NPC should not be knocked back")


func test_apply_knockback_sets_stun_timer() -> void:
	_npc.apply_knockback(Vector2.RIGHT)
	assert_gt(_npc._stun_timer, 0.0,
		"A knocked-back NPC should be stunned for a short period")


func test_apply_knockback_sets_knockback_active_flag() -> void:
	_npc.apply_knockback(Vector2.RIGHT)
	assert_true(_npc._knockback_active,
		"apply_knockback should set _knockback_active to true")


func test_npc_snaps_to_grid_after_knockback() -> void:
	# Position the NPC off-grid (e.g. 7 px offset inside a cell).
	_npc.global_position = Vector2(39.0, 55.0)
	_npc.apply_knockback(Vector2.RIGHT)
	# Drain the knockback velocity to zero so the snap fires.
	_npc._knockback_velocity = Vector2.ZERO
	# A single physics tick should trigger the end-of-knockback snap.
	_npc._physics_process(0.016)
	var gp: Vector2 = _npc.global_position
	assert_eq(fmod(gp.x, 16.0), 0.0,
		"NPC x position should be snapped to 16-px grid after knockback")
	assert_eq(fmod(gp.y, 16.0), 0.0,
		"NPC y position should be snapped to 16-px grid after knockback")


func test_npc_snaps_to_grid_even_when_stationary() -> void:
	# STATIONARY NPCs never move, so they must snap immediately after knockback.
	_npc.movement_mode = _npc.MovementMode.STATIONARY
	_npc.global_position = Vector2(25.0, 41.0)
	_npc.apply_knockback(Vector2.DOWN)
	_npc._knockback_velocity = Vector2.ZERO
	_npc._physics_process(0.016)
	var gp: Vector2 = _npc.global_position
	assert_eq(fmod(gp.x, 16.0), 0.0,
		"Stationary NPC x should be on-grid after knockback")
	assert_eq(fmod(gp.y, 16.0), 0.0,
		"Stationary NPC y should be on-grid after knockback")


func test_invincible_npc_not_snapped_after_zero_velocity() -> void:
	# Invincible NPCs bypass apply_knockback entirely, so _knockback_active
	# should never be set for them — ensuring no grid snap is ever attempted.
	_npc.invincible = true
	_npc.apply_knockback(Vector2.RIGHT)
	assert_false(_npc._knockback_active,
		"Invincible NPC should not have _knockback_active set after apply_knockback")


# ---------------------------------------------------------------------------
# Player reference (set_player_reference)
# ---------------------------------------------------------------------------

func test_set_player_reference_stores_reference() -> void:
	var dummy_player: Node2D = Node2D.new()
	add_child_autoqfree(dummy_player)
	_npc.set_player_reference(dummy_player)
	assert_eq(_npc._player_ref, dummy_player,
		"set_player_reference should store the provided node as _player_ref")


# ---------------------------------------------------------------------------
# Patrol reset behaviour
# ---------------------------------------------------------------------------

func test_reset_patrol_clears_player_ref() -> void:
	var dummy_player: Node2D = Node2D.new()
	add_child_autoqfree(dummy_player)
	_npc.set_player_reference(dummy_player)
	_npc._patrol_was_chasing = true
	_npc.reset_patrol()
	assert_eq(_npc._player_ref, null,
		"reset_patrol should clear the stored player reference")


func test_reset_patrol_clears_chasing_flag() -> void:
	_npc._patrol_was_chasing = true
	_npc.reset_patrol()
	assert_false(_npc._patrol_was_chasing,
		"reset_patrol should clear the _patrol_was_chasing flag")


# ---------------------------------------------------------------------------
# A* pathfinder (set_pathfinder)
# ---------------------------------------------------------------------------

func test_set_pathfinder_stores_reference() -> void:
	var pf: Object = preload("res://scripts/pathfinder.gd").new()
	_npc.set_pathfinder(pf)
	assert_eq(_npc._pathfinder, pf,
		"set_pathfinder should store the supplied RoomPathfinder as _pathfinder")


func test_set_pathfinder_accepts_null() -> void:
	var pf: Object = preload("res://scripts/pathfinder.gd").new()
	_npc.set_pathfinder(pf)
	_npc.set_pathfinder(null)
	assert_eq(_npc._pathfinder, null,
		"set_pathfinder(null) should clear the stored pathfinder reference")

