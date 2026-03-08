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

signal interaction_requested
## Emitted once per room visit when a PATROL NPC first spots the player.
## Carries the detection_dialog string.
signal player_detected(dialog: String)
## Emitted each time this hostile NPC's HitArea contacts the player.
signal player_hit

const KNOCKBACK_SPEED: float = 400.0
const KNOCKBACK_THRESHOLD: float = 5.0
const KNOCKBACK_DECAY_MULTIPLIER: float = 6.0
## How long the enemy freezes after being knocked back before resuming AI.
const STUN_DURATION: float = 0.5
## Inner and outer bounds for KEEP_DISTANCE mode.
const KEEP_DIST_MARGIN: float = 50.0
## Clamp bounds keeping NPCs inside the room walls (640×480 room, 24 px walls,
## 8 px half-body).  Prevents knockback from pushing enemies through exit gaps.
const ROOM_BOUNDS_MIN: Vector2 = Vector2(32.0, 32.0)
const ROOM_BOUNDS_MAX: Vector2 = Vector2(608.0, 448.0)
const FRIENDLY_COLOR: Color = Color(0.2, 0.4, 0.9)
const HOSTILE_COLOR: Color = Color(0.8, 0.1, 0.1)
## Flash color used when any NPC takes damage.
const DAMAGE_FLASH_COLOR: Color = Color(1.0, 0.3, 0.3)
## Fill colour for the visible detection cone overlay.
const CONE_COLOR: Color = Color(1.0, 1.0, 0.0, 0.25)
## Proximity threshold (px) for considering a patrol waypoint reached.
const PATROL_ARRIVAL_THRESHOLD: float = 8.0
var hp: int
var is_paused: bool = false
var _wander_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _player_ref: Node = null
var _knockback_velocity: Vector2 = Vector2.ZERO
var _stun_timer: float = 0.0
var _shoot_timer: float = 0.0
var _patrol_index: int = 0
var _patrol_pause_timer: float = 0.0
var _patrol_was_chasing: bool = false
## Prevents detection_dialog from firing more than once per room visit.
var _detection_triggered: bool = false
## Current facing direction (normalised); used for cone detection and drawing.
var _facing_dir: Vector2 = Vector2.RIGHT
## A* pathfinder supplied by the room loader; null when not using A*.
var _pathfinder = null

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	hp = max_hp
	if is_hostile:
		add_to_group("enemy")
		sprite.color = Color(0.8, 0.1, 0.1)
	else:
		add_to_group("npc")
		sprite.color = Color(0.2, 0.4, 0.9)
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


func _physics_process(delta: float) -> void:
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_SPEED * delta * KNOCKBACK_DECAY_MULTIPLIER)
	_stun_timer = maxf(0.0, _stun_timer - delta)

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
			global_position = global_position.clamp(ROOM_BOUNDS_MIN, ROOM_BOUNDS_MAX)
		return

	# Briefly frozen after knockback ends before resuming chase.
	if _stun_timer > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var mode: MovementMode = movement_mode
	if mode == MovementMode.DEFAULT:
		mode = MovementMode.CHASE if is_hostile else MovementMode.WANDER

	# Determine whether the player is within detection range.
	var in_range: bool = true
	if is_hostile and _player_ref and detection_range > 0.0:
		if use_cone_detection:
			in_range = _is_player_in_cone()
		else:
			in_range = global_position.distance_to(_player_ref.global_position) <= detection_range

	# PATROL is handled separately: it is the base mode and CHASE is the
	# activated state when a hostile NPC detects the player.
	if mode == MovementMode.PATROL:
		if is_hostile and _player_ref and detection_range > 0.0 and in_range:
			if not _patrol_was_chasing:
				_patrol_was_chasing = true
				if detection_dialog != "" and not _detection_triggered:
					_detection_triggered = true
					player_detected.emit(detection_dialog)
			_chase_player()
			if can_shoot:
				_shoot_timer -= delta
				if _shoot_timer <= 0.0:
					_shoot_timer = shoot_cooldown
					_fire_projectile()
		else:
			if _patrol_was_chasing:
				_patrol_was_chasing = false
				_resume_patrol_from_nearest()
			_patrol_move(delta)
		_update_facing_and_redraw(velocity)
		move_and_slide()
		if not invincible:
			global_position = global_position.clamp(ROOM_BOUNDS_MIN, ROOM_BOUNDS_MAX)
		return

	if not in_range:
		# Use idle behaviour while player is far away.
		var idle: MovementMode = idle_movement_mode
		if idle == MovementMode.DEFAULT:
			idle = MovementMode.WANDER
		match idle:
			MovementMode.STATIONARY:
				velocity = Vector2.ZERO
			MovementMode.WANDER:
				_wander(delta)
			_:
				velocity = Vector2.ZERO
	else:
		match mode:
			MovementMode.STATIONARY:
				velocity = Vector2.ZERO
			MovementMode.WANDER:
				_wander(delta)
			MovementMode.CHASE:
				if _player_ref:
					_chase_player()
				else:
					velocity = Vector2.ZERO
			MovementMode.KEEP_DISTANCE:
				if _player_ref:
					_keep_distance()
				else:
					velocity = Vector2.ZERO

		# Ranged attack when in range and able to shoot.
		if can_shoot and _player_ref:
			_shoot_timer -= delta
			if _shoot_timer <= 0.0:
				_shoot_timer = shoot_cooldown
				_fire_projectile()

	_update_facing_and_redraw(velocity)
	move_and_slide()
	# Prevent knockback from pushing NPCs through exit gaps in the walls.
	# Invincible NPCs (gate blockers) are exempt so they can sit in exit gaps.
	if not invincible:
		global_position = global_position.clamp(ROOM_BOUNDS_MIN, ROOM_BOUNDS_MAX)


## Called by the game controller to give this NPC a reference to the player.
func set_player_reference(player: Node) -> void:
	_player_ref = player


## Called by the game controller to supply an A* pathfinder built for the
## current room.  Pass null to revert to raycasting navigation.
func set_pathfinder(pf) -> void:
	_pathfinder = pf


func _chase_player() -> void:
	velocity = _navigate_toward(_player_ref.global_position) * move_speed


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
		if randf() < 0.6:
			# Only move in one cardinal direction at a time (no diagonal wander).
			var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
			_wander_dir = dirs[randi() % dirs.size()]
		else:
			_wander_dir = Vector2.ZERO
	velocity = _wander_dir * (move_speed * 0.5)


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
		velocity = (target - global_position).normalized() * move_speed


## Called externally (e.g. after a cinematic kick-back) to make this NPC
## immediately resume its patrol instead of continuing to chase the player.
## Clears _player_ref so detection logic does not immediately re-engage;
## the reference is restored next time set_player_reference() is called
## (which happens automatically when the room is re-entered).
func reset_patrol() -> void:
	_patrol_was_chasing = false
	_player_ref = null
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
	sprite.color = DAMAGE_FLASH_COLOR
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_property(sprite, "color", base_color, 0.0)
	if hp <= 0:
		queue_free()


func apply_knockback(direction: Vector2) -> void:
	if invincible:
		return
	_knockback_velocity = direction.normalized() * KNOCKBACK_SPEED
	_stun_timer = STUN_DURATION


## Returns true when the player is inside the forward-facing detection cone.
## The cone is centred on _facing_dir with a half-angle of detection_cone_angle/2
## and radius detection_range.
func _is_player_in_cone() -> bool:
	if _player_ref == null:
		return false
	var to_player: Vector2 = _player_ref.global_position - global_position
	if to_player.length() > detection_range:
		return false
	var angle_diff: float = _facing_dir.angle_to(to_player)
	return absf(angle_diff) <= deg_to_rad(detection_cone_angle * 0.5)


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
		player_hit.emit()
		# Cinematic NPCs handle player movement themselves; skip direct damage/knockback.
		if not cinematic_kick_back:
			body.take_damage(1)
			body.apply_knockback(direction)
	elif not is_hostile and body.is_in_group("player"):
		interaction_requested.emit()
