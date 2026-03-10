extends CharacterBody2D

const NavigationUtils = preload("res://scripts/navigation_utils.gd")

## Whether this NPC is a hostile enemy (chases and attacks on contact) or a
## friendly NPC (wanders and can be talked to).
@export var is_hostile: bool = false

## Lines shown when the player interacts with a friendly NPC.
@export var dialog_lines: Array = ["Hello, traveler!", "Good luck on your quest!"]

## Optional pool of dialog arrays for random variation.  When non-empty, one
## array is chosen at random each interaction and appended after dialog_lines.
@export var dialog_pools: Array = []

## Lines always appended at the very end of every interaction, after dialog_lines
## and any randomly chosen pool.  Useful for a fixed closing beat.
@export var dialog_suffix: Array = []

## Display name shown in the dialog box header when this NPC speaks.
@export var npc_name: String = ""

@export var move_speed: float = 60.0
@export var max_hp: int = 3

## Controls how this NPC moves.  DEFAULT falls back to CHASE when is_hostile
## is true, and WANDER otherwise, preserving existing behaviour.
enum MovementMode { DEFAULT, STATIONARY, WANDER, CHASE, KEEP_DISTANCE, PATROL }
@export var movement_mode: MovementMode = MovementMode.DEFAULT

## Internal state machine.  Each value maps to a per-frame handler called from
## _physics_process().  Transitions are made via transition_to() which logs
## every change in debug builds.
enum State { IDLE, WANDER, PATROL, CHASE, KEEP_DISTANCE, STUNNED }

## Movement mode used when the player is outside detection_range.
## Only applied to hostile NPCs; friendly NPCs always use their movement_mode.
@export var idle_movement_mode: MovementMode = MovementMode.WANDER

## How close the player must get before this enemy activates.
## Set to 0 to always be active.
@export var detection_range: float = 200.0

## Preferred stand-off distance used by the KEEP_DISTANCE mode.
@export var keep_distance_preferred: float = 180.0

## Ordered list of world-space positions this NPC walks between when
## movement_mode is PATROL.  The NPC loops back to the first point after
## reaching the last one.
@export var patrol_points: Array[Vector2] = []

## Seconds to pause at each waypoint before moving to the next.
@export var patrol_pause_duration: float = 0.0

## When true this enemy fires projectiles at the player while in range.
@export var can_shoot: bool = false
@export var projectile_scene: PackedScene = null
@export var shoot_cooldown: float = 2.0

## Line spoken (and signal emitted) the first time a PATROL NPC detects the
## player each room visit.  Leave empty to disable.
@export var detection_dialog: String = ""

## When true, contacting the player emits player_hit and triggers the cinematic
## kick-back sequence rather than dealing direct damage / knockback.
## Set this via the Inspector on any NPC that should play a cinematic instead.
@export var cinematic_kick_back: bool = false

## When true, player detection uses a forward-facing cone instead of a full
## radius.  The cone is also rendered as a transparent yellow overlay.
@export var use_cone_detection: bool = false
## When true, this NPC uses A* grid pathfinding (via a RoomPathfinder supplied
## by main.gd) instead of short-range raycasting to navigate around obstacles.
@export var use_astar: bool = false
## Full angle of the detection cone in degrees (e.g. 90 = ±45° either side of
## the facing direction).
@export var detection_cone_angle: float = 90.0

## When true this NPC is immune to damage and knockback and is never clamped
## to the room bounds (allows gate NPCs to sit in exit gaps).
@export var invincible: bool = false

## Optional colour override for the NPC sprite.  When alpha > 0 this colour
## replaces the default friendly (blue) or hostile (red) sprite colour.
## Useful for giving special NPCs like readable items a distinct appearance.
@export var custom_sprite_color: Color = Color(0, 0, 0, 0)

## When > 0, hostile NPCs in CHASE mode add a random positional offset to
## their target each frame.  Use this on groups of enemies so they spread out
## rather than stacking on top of each other.
@export var chase_random_offset: float = 0.0

## When non-zero, overrides the knockback direction applied to the player on
## contact.  Normally the direction is derived from the collision angle
## (player_position − npc_position).  Set this to a fixed world-space
## direction (e.g. Vector2(1, 0) to always push east) so that enemies like
## enchanted brooms always sweep the player toward the exit regardless of the
## contact angle.
@export var knockback_direction_override: Vector2 = Vector2.ZERO

## If non-empty, give this key id to the player after dialog and then
## remove the NPC.  Only activates once gives_key_flag (if set) is true.
@export var gives_key_id: String = ""
## GameState flag that must be set before gives_key_id activates.
@export var gives_key_flag: String = ""
## Dialog shown when gives_key_flag is not yet set (or before any flag gate).
@export var pre_flag_dialog: Array = []

## If non-empty, the player must carry this key id for the NPC to show
## key_accept_dialog and remove itself.
@export var requires_key_id: String = ""
## Dialog shown when the player has the required key.
@export var key_accept_dialog: Array = []

## GameState flag set after a normal (no-key) interaction with this NPC.
@export var sets_game_flag: String = ""
## GameState flag gate for non-key-giving NPCs that still need conditional
## dialog (e.g. cats that should stay silent until a flag is set).
@export var requires_flag: String = ""

## Key item ID that, when held by the player, causes this NPC to show
## after_key_dialog instead of the normal dialog_lines.
@export var after_key_id: String = ""
## Dialog shown when the player already holds after_key_id.
@export var after_key_dialog: Array = []

## Item ID that the player must carry to progress past this NPC's gate
## (checked but NOT consumed). If empty, no item gate applies.
@export var requires_item: String = ""
## Dialog shown when requires_item is set but the player does not have it.
@export var requires_item_dialog: Array = []

signal interaction_requested
## Emitted once per room visit when a PATROL NPC first spots the player.
## Carries the detection_dialog string.
signal player_detected(dialog: String)
## Emitted each time this hostile NPC's HitArea contacts the player.
signal player_hit
## Emitted whenever this NPC takes damage (after HP is reduced).
signal damaged

const KNOCKBACK_SPEED: float = GameConfig.NPC_KNOCKBACK_SPEED
const KNOCKBACK_THRESHOLD: float = 5.0
const KNOCKBACK_DECAY_MULTIPLIER: float = GameConfig.KNOCKBACK_DECAY_MULTIPLIER
const GRID_SIZE: int = GameConfig.GRID_SIZE
## How long the enemy freezes after being knocked back before resuming AI.
const STUN_DURATION: float = 0.5
## Inner and outer bounds for KEEP_DISTANCE mode.
const KEEP_DIST_MARGIN: float = 50.0
## Margin (px) inset from the room rect edges used for wander/knockback clamping.
const _BOUNDS_MARGIN: float = 32.0
const FRIENDLY_COLOR: Color = Color(0.2, 0.4, 0.9)
const HOSTILE_COLOR: Color = Color(0.8, 0.1, 0.1)
## Flash color used when any NPC takes damage.
const DAMAGE_FLASH_COLOR: Color = Color(1.0, 0.3, 0.3)
## Fill colour for the visible detection cone overlay.
const CONE_COLOR: Color = Color(1.0, 1.0, 0.0, 0.25)
## Proximity threshold (px) for considering a patrol waypoint reached.
const PATROL_ARRIVAL_THRESHOLD: float = GameConfig.PATROL_ARRIVAL_THRESHOLD
var hp: int
var is_paused: bool = false
var _wander_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _player_ref: Node = null
var _knockback_velocity: Vector2 = Vector2.ZERO
var _knockback_active: bool = false
var _stun_timer: float = 0.0
var _shoot_timer: float = 0.0
var _patrol_index: int = 0
var _patrol_pause_timer: float = 0.0
var _patrol_was_chasing: bool = false
## Prevents detection_dialog from firing more than once per room visit.
var _detection_triggered: bool = false
## Current facing direction (normalised); used for cone detection and drawing.
var _facing_dir: Vector2 = Vector2.RIGHT
## Per-room clamp bounds set by set_room_bounds().  Defaults are permissive
## so NPCs are not artificially clamped before room_manager calls
## set_room_bounds(); room collision geometry prevents movement beyond walls.
var _room_bounds_min: Vector2 = Vector2(_BOUNDS_MARGIN, _BOUNDS_MARGIN)
var _room_bounds_max: Vector2 = Vector2(1e6 - _BOUNDS_MARGIN, 1e6 - _BOUNDS_MARGIN)
## True once exported patrol points have been shifted to world-space coordinates.
var _patrol_points_adjusted: bool = false
## A* pathfinder supplied by the room loader; null when not using A*.
var _pathfinder = null
## Current state-machine state; drives which per-frame handler runs.
var _state: State = State.IDLE
## Cached by _update_state(); true when the player is inside detection_range
## (or the forward cone when use_cone_detection is on).  Read by the ranged-
## attack gate after the per-state dispatch.
var _in_range: bool = false

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	hp = max_hp
	if is_hostile:
		add_to_group("enemy")
		sprite.color = Color(0.8, 0.1, 0.1)
	else:
		add_to_group("npc")
		sprite.color = Color(0.2, 0.4, 0.9)
	if custom_sprite_color.a > 0.0:
		sprite.color = custom_sprite_color
	if cinematic_kick_back:
		add_to_group("cinematic_kick_back")
	$HitArea.body_entered.connect(_on_hit_area_body_entered)
	_collect_patrol_points_from_children()
	# Seed the facing direction toward the first patrol waypoint so the cone
	# is oriented correctly before the first physics tick.
	if use_cone_detection and not patrol_points.is_empty():
		var offset: Vector2 = patrol_points[0] - global_position
		if offset.length_squared() > 0.0:
			_facing_dir = offset.normalized()
	# Initialise state directly (no transition hooks / logging during setup).
	_state = _initial_state()


func _physics_process(delta: float) -> void:
	_knockback_velocity = CombatUtils.decay_knockback(_knockback_velocity, KNOCKBACK_SPEED, delta, KNOCKBACK_DECAY_MULTIPLIER)
	_stun_timer = maxf(0.0, _stun_timer - delta)

	# Detect knockback end: snap back to the nearest 16-px grid cell so the
	# NPC stays aligned even if it ends up stationary after the knockback.
	if _knockback_active and _knockback_velocity.length() <= KNOCKBACK_THRESHOLD:
		_knockback_active = false
		global_position = global_position.snapped(Vector2.ONE * GRID_SIZE)

	if is_paused:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# While knocked back: fly freely, skip all AI.
	if _knockback_velocity.length() > KNOCKBACK_THRESHOLD:
		velocity = _knockback_velocity
		move_and_slide()
		# Feed the post-collision (wall-slid) velocity back so the NPC
		# slides along walls instead of being pushed into them.
		_knockback_velocity = velocity
		if not invincible:
			global_position = global_position.clamp(_room_bounds_min, _room_bounds_max)
		return
	if _stun_timer > 0.0:
		if _state != State.STUNNED:
			transition_to(State.STUNNED)
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Determine the correct state for this frame and transition if needed.
	_update_state()

	match _state:
		State.IDLE:          _process_idle()
		State.WANDER:        _process_wander(delta)
		State.PATROL:        _process_patrol(delta)
		State.CHASE:         _process_chase()
		State.KEEP_DISTANCE: _process_keep_distance()
		State.STUNNED:       _process_idle()  # frozen during stun; _update_state handles recovery

	# Ranged attack fired from any active state where the player is in range.
	if can_shoot and _player_ref and _in_range:
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_timer = shoot_cooldown
			_fire_projectile()

	_update_facing_and_redraw(velocity)
	move_and_slide()
	# Prevent knockback from pushing NPCs through exit gaps in the walls.
	# Invincible NPCs (gate blockers) are exempt so they can sit in exit gaps.
	if not invincible:
		global_position = global_position.clamp(_room_bounds_min, _room_bounds_max)


## Called by the game controller to give this NPC a reference to the player.
func set_player_reference(player: Node) -> void:
	_player_ref = player


## Called by the game controller after a room is loaded to set wander/knockback
## clamp bounds from the room's actual size.
func set_room_bounds(room_rect: Rect2) -> void:
	_room_bounds_min = room_rect.position + Vector2(_BOUNDS_MARGIN, _BOUNDS_MARGIN)
	_room_bounds_max = room_rect.end - Vector2(_BOUNDS_MARGIN, _BOUNDS_MARGIN)
	# Exported patrol points are in room-local coordinates.  When the room is
	# placed at a non-zero world position (e.g. after a room transition) the
	# points must be shifted to world space once.
	if not _patrol_points_adjusted and not patrol_points.is_empty():
		var offset: Vector2 = room_rect.position
		for i in range(patrol_points.size()):
			patrol_points[i] += offset
		_patrol_points_adjusted = true


## Called by the game controller to supply an A* pathfinder built for the
## current room.  Pass null to revert to raycasting navigation.
func set_pathfinder(pf) -> void:
	_pathfinder = pf


# ---------------------------------------------------------------------------
# State machine
# ---------------------------------------------------------------------------

## Derive the starting State from movement_mode so _ready() can set _state
## directly (without triggering transition hooks or debug logging).
func _initial_state() -> State:
	var mode: MovementMode = movement_mode
	if mode == MovementMode.DEFAULT:
		mode = MovementMode.CHASE if is_hostile else MovementMode.WANDER
	match mode:
		MovementMode.PATROL:        return State.PATROL
		MovementMode.WANDER:        return State.WANDER
		MovementMode.CHASE:         return State.CHASE
		MovementMode.KEEP_DISTANCE: return State.KEEP_DISTANCE
		_:                          return State.IDLE


## Evaluate movement conditions and trigger the appropriate transition.
## Called once per physics frame after early-exit guards have been checked.
func _update_state() -> void:
	var mode: MovementMode = movement_mode
	if mode == MovementMode.DEFAULT:
		mode = MovementMode.CHASE if is_hostile else MovementMode.WANDER

	_in_range = _compute_in_range()

	if mode == MovementMode.PATROL:
		# PATROL: patrol normally; switch to CHASE when hostile and player detected.
		if is_hostile and _player_ref and detection_range > 0.0 and _in_range:
			if _state != State.CHASE:
				transition_to(State.CHASE)
		else:
			if _state != State.PATROL:
				transition_to(State.PATROL)
	elif not _in_range:
		var desired: State = _idle_mode_to_state()
		if _state != desired:
			transition_to(desired)
	else:
		var desired: State = _active_mode_to_state(mode)
		if _state != desired:
			transition_to(desired)


## True when the player is within detection_range (or the forward cone).
## Returns true when there is no player reference or detection is disabled.
func _compute_in_range() -> bool:
	if not (is_hostile and _player_ref and detection_range > 0.0):
		return true
	if use_cone_detection:
		return _is_player_in_cone()
	return global_position.distance_to(_player_ref.global_position) <= detection_range


## Map idle_movement_mode to the corresponding State.
func _idle_mode_to_state() -> State:
	var idle: MovementMode = idle_movement_mode
	if idle == MovementMode.DEFAULT:
		idle = MovementMode.WANDER
	match idle:
		MovementMode.WANDER: return State.WANDER
		_:                   return State.IDLE


## Map an active MovementMode to the corresponding State.
func _active_mode_to_state(mode: MovementMode) -> State:
	match mode:
		MovementMode.WANDER:        return State.WANDER
		MovementMode.CHASE:         return State.CHASE
		MovementMode.KEEP_DISTANCE: return State.KEEP_DISTANCE
		_:                          return State.IDLE


## Transition to new_state, calling exit/enter hooks and logging in debug builds.
func transition_to(new_state: State) -> void:
	var old_state: State = _state
	_exit_state(old_state)
	_state = new_state
	_enter_state(new_state, old_state)
	if OS.is_debug_build():
		# State.keys() returns names in definition order; relies on the enum
		# values being sequential (0, 1, 2, …) which GDScript guarantees by default.
		print("[NPC %s] %s → %s" % [name, State.keys()[old_state], State.keys()[new_state]])


## Returns the current state-machine state.  Useful for external queries and tests.
func get_current_state() -> State:
	return _state


## Called when leaving a state.  Override for per-state teardown if needed.
func _exit_state(_s: State) -> void:
	pass


## Called when entering a state.  Handles side-effects for PATROL↔CHASE.
func _enter_state(new_state: State, from_state: State) -> void:
	match new_state:
		State.PATROL:
			# Returning from chase back to patrol: resume from the nearest waypoint.
			if from_state == State.CHASE:
				_patrol_was_chasing = false
				_resume_patrol_from_nearest()
		State.CHASE:
			# Engaging chase from patrol mode: set flag and optionally emit detection.
			if movement_mode == MovementMode.PATROL and not _patrol_was_chasing:
				_patrol_was_chasing = true
				if detection_dialog != "" and not _detection_triggered:
					_detection_triggered = true
					player_detected.emit(detection_dialog)


# ---------------------------------------------------------------------------
# Per-state handlers — each sets velocity; move_and_slide() is called once
# after the dispatch in _physics_process().
# ---------------------------------------------------------------------------

func _process_idle() -> void:
	velocity = Vector2.ZERO


func _process_wander(delta: float) -> void:
	_wander(delta)


func _process_patrol(delta: float) -> void:
	_patrol_move(delta)


func _process_chase() -> void:
	if _player_ref:
		_chase_player()
	else:
		velocity = Vector2.ZERO


func _process_keep_distance() -> void:
	if _player_ref:
		_keep_distance()
	else:
		velocity = Vector2.ZERO


func _chase_player() -> void:
	var target: Vector2 = _player_ref.global_position
	if chase_random_offset > 0.0:
		target += Vector2(randf_range(-chase_random_offset, chase_random_offset),
				randf_range(-chase_random_offset, chase_random_offset))
	velocity = _navigate_toward(target) * move_speed


## Returns the best direction to move toward `target` while steering around
## physics obstacles.  Uses A* grid pathfinding when a pathfinder has been
## supplied (use_astar NPCs), otherwise falls back to the legacy short-range
## raycasting approach.
func _navigate_toward(target: Vector2) -> Vector2:
	if _pathfinder != null:
		return _pathfinder.get_next_direction(global_position, target)

	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state

	# Build exclusion list: skip this NPC and the player so we only detect
	# static obstacles (walls, furniture).
	var excl: Array[RID] = [get_rid()]
	if _player_ref is CollisionObject2D:
		excl.append((_player_ref as CollisionObject2D).get_rid())
	return NavigationUtils.navigate_toward(global_position, target, space, excl)


func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.5, 3.5)
		if randf() < GameConfig.WANDER_PROBABILITY:
			# Only move in one cardinal direction at a time (no diagonal wander).
			var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
			_wander_dir = dirs[randi() % dirs.size()]
		else:
			_wander_dir = Vector2.ZERO
	velocity = _wander_dir * (move_speed * GameConfig.WANDER_SPEED_FACTOR)


## Tries to stay at roughly keep_distance_preferred pixels from the player
## while keeping the player in sight.  Retreats when too close, closes
## the gap when too far.
func _keep_distance() -> void:
	var to_player: Vector2 = _player_ref.global_position - global_position
	var dist: float = to_player.length()
	var min_dist: float = keep_distance_preferred - KEEP_DIST_MARGIN
	var max_dist: float = keep_distance_preferred + KEEP_DIST_MARGIN
	if dist < min_dist:
		velocity = -to_player.normalized() * move_speed
	elif dist > max_dist:
		velocity = to_player.normalized() * move_speed * 0.6
	else:
		velocity = Vector2.ZERO


## Fire a projectile toward the player.
func _fire_projectile() -> void:
	if projectile_scene == null or _player_ref == null:
		return
	var projectile: Node = projectile_scene.instantiate()
	var dir: Vector2 = (_player_ref.global_position - global_position).normalized()
	projectile.setup(dir, true)
	# Add to the current scene root so the projectile shares the same space
	# as the player regardless of the NPC's position in the hierarchy.
	get_tree().current_scene.add_child(projectile)
	(projectile as Node2D).global_position = global_position
	# Prevent the projectile from colliding with the NPC that fired it.
	(projectile as CharacterBody2D).add_collision_exception_with(self)


func _collect_patrol_points_from_children() -> void:
	if not patrol_points.is_empty():
		return
	var tagged: Array = []
	for child in get_children():
		if child is Marker2D and child.name.begins_with("PatrolPoint"):
			var suffix: String = (child.name as String).substr(len("PatrolPoint"))
			var idx: int = suffix.to_int() if suffix.is_valid_int() else -1
			tagged.append([idx, child.global_position])
	tagged.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry in tagged:
		patrol_points.append(entry[1])


func _patrol_move(delta: float) -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return
	if _patrol_pause_timer > 0.0:
		_patrol_pause_timer -= delta
		velocity = Vector2.ZERO
		return
	var target: Vector2 = patrol_points[_patrol_index]
	if global_position.distance_to(target) <= PATROL_ARRIVAL_THRESHOLD:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		_patrol_pause_timer = patrol_pause_duration
		velocity = Vector2.ZERO
	else:
		velocity = _navigate_toward(target) * move_speed


## Called externally (e.g. after a cinematic kick-back) to make this NPC
## immediately resume its patrol instead of continuing to chase the player.
## Clears _player_ref so detection logic does not immediately re-engage;
## the reference is restored next time set_player_reference() is called
## (which happens automatically when the room is re-entered).
func reset_patrol() -> void:
	_patrol_was_chasing = false
	_player_ref = null
	# Assign state directly to skip _exit_state/_enter_state side-effects (e.g.
	# _resume_patrol_from_nearest is called explicitly below, so we must not let
	# _enter_state(PATROL, CHASE) call it a second time).
	_state = State.PATROL
	_resume_patrol_from_nearest()


func _resume_patrol_from_nearest() -> void:
	if patrol_points.is_empty():
		return
	var nearest_idx: int = 0
	var nearest_dist: float = global_position.distance_to(patrol_points[0])
	for i in range(1, patrol_points.size()):
		var d: float = global_position.distance_to(patrol_points[i])
		if d < nearest_dist:
			nearest_dist = d
			nearest_idx = i
	_patrol_index = nearest_idx


func take_damage(amount: int) -> void:
	if invincible:
		return
	hp -= amount
	var base_color: Color = HOSTILE_COLOR if is_hostile else FRIENDLY_COLOR
	CombatUtils.flash_damage(sprite, DAMAGE_FLASH_COLOR, base_color)
	if hp <= 0:
		queue_free()
	else:
		damaged.emit()


func apply_knockback(direction: Vector2) -> void:
	if invincible:
		return
	_knockback_velocity = direction.normalized() * KNOCKBACK_SPEED
	_stun_timer = STUN_DURATION
	_knockback_active = true


## Returns true when the player is inside the forward-facing detection cone
## AND no static obstacle blocks the line of sight.
## The cone is centred on _facing_dir with a half-angle of detection_cone_angle/2
## and radius detection_range.
func _is_player_in_cone() -> bool:
	if _player_ref == null:
		return false
	var to_player: Vector2 = _player_ref.global_position - global_position
	if to_player.length() > detection_range:
		return false
	var angle_diff: float = _facing_dir.angle_to(to_player)
	if absf(angle_diff) > deg_to_rad(detection_cone_angle * 0.5):
		return false
	# Line-of-sight check: cast a ray to the player and reject if a static
	# body (wall or furniture) is in the way.
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, _player_ref.global_position)
	query.exclude = [get_rid(), _player_ref.get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()


## Updates _facing_dir from vel (when moving) and marks the canvas item dirty
## so the detection cone overlay is redrawn this frame.  Called at the end of
## every active physics-process path so the cone always reflects current state.
func _update_facing_and_redraw(vel: Vector2) -> void:
	if vel.length_squared() > 0.01:
		_facing_dir = vel.normalized()
	if use_cone_detection:
		queue_redraw()


## Draws the transparent-yellow detection cone when use_cone_detection is true.
func _draw() -> void:
	if not use_cone_detection:
		return
	var half_rad: float = deg_to_rad(detection_cone_angle * 0.5)
	var base_angle: float = _facing_dir.angle()
	var num_segments: int = 16
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(num_segments + 1):
		var t: float = float(i) / float(num_segments)
		var a: float = base_angle - half_rad + t * (half_rad * 2.0)
		points.append(Vector2(cos(a), sin(a)) * detection_range)
	draw_polygon(points, PackedColorArray([CONE_COLOR]))


func _on_hit_area_body_entered(body: Node) -> void:
	if is_hostile and body.is_in_group("player"):
		var direction: Vector2 = ((body as Node2D).global_position - global_position).normalized()
		if knockback_direction_override != Vector2.ZERO:
			direction = knockback_direction_override.normalized()
		player_hit.emit()
		# Cinematic NPCs handle player movement themselves; skip direct damage/knockback.
		if not cinematic_kick_back:
			body.take_damage(1)
			body.apply_knockback(direction)
	elif not is_hostile and body.is_in_group("player"):
		interaction_requested.emit()
