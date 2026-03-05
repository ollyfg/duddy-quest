extends CharacterBody2D

## Whether this NPC is a hostile enemy (chases and attacks on contact) or a
## friendly NPC (wanders and can be talked to).
@export var is_hostile: bool = false

## Lines shown when the player interacts with a friendly NPC.
@export var dialog_lines: Array = ["Hello, traveler!", "Good luck on your quest!"]

@export var move_speed: float = 60.0
@export var max_hp: int = 3

## Controls how this NPC moves.  DEFAULT falls back to CHASE when is_hostile
## is true, and WANDER otherwise, preserving existing behaviour.
enum MovementMode { DEFAULT, STATIONARY, WANDER, CHASE, KEEP_DISTANCE }
@export var movement_mode: MovementMode = MovementMode.DEFAULT

## Movement mode used when the player is outside detection_range.
## Only applied to hostile NPCs; friendly NPCs always use their movement_mode.
@export var idle_movement_mode: MovementMode = MovementMode.WANDER

## How close the player must get before this enemy activates.
## Set to 0 to always be active.
@export var detection_range: float = 200.0

## Preferred stand-off distance used by the KEEP_DISTANCE mode.
@export var keep_distance_preferred: float = 180.0

## When true this enemy fires projectiles at the player while in range.
@export var can_shoot: bool = false
@export var projectile_scene: PackedScene = null
@export var shoot_cooldown: float = 2.0

signal interaction_requested

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

var hp: int
var is_paused: bool = false
var _wander_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _player_ref: Node = null
var _knockback_velocity: Vector2 = Vector2.ZERO
var _stun_timer: float = 0.0
var _shoot_timer: float = 0.0

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	hp = max_hp
	if is_hostile:
		add_to_group("enemy")
		sprite.color = Color(0.8, 0.1, 0.1)
	else:
		add_to_group("npc")
		sprite.color = Color(0.2, 0.4, 0.9)
	$HitArea.body_entered.connect(_on_hit_area_body_entered)


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
		in_range = global_position.distance_to(_player_ref.global_position) <= detection_range

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

	move_and_slide()
	# Prevent knockback from pushing NPCs through exit gaps in the walls.
	global_position = global_position.clamp(ROOM_BOUNDS_MIN, ROOM_BOUNDS_MAX)


## Called by the game controller to give this NPC a reference to the player.
func set_player_reference(player: Node) -> void:
	_player_ref = player


func _chase_player() -> void:
	velocity = (_player_ref.global_position - global_position).normalized() * move_speed


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


func take_damage(amount: int) -> void:
	hp -= amount
	var base_color: Color = HOSTILE_COLOR if is_hostile else FRIENDLY_COLOR
	sprite.color = DAMAGE_FLASH_COLOR
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_property(sprite, "color", base_color, 0.0)
	if hp <= 0:
		queue_free()


func apply_knockback(direction: Vector2) -> void:
	_knockback_velocity = direction.normalized() * KNOCKBACK_SPEED
	_stun_timer = STUN_DURATION


func _on_hit_area_body_entered(body: Node) -> void:
	if is_hostile and body.is_in_group("player"):
		var direction: Vector2 = ((body as Node2D).global_position - global_position).normalized()
		body.take_damage(1)
		body.apply_knockback(direction)
	elif not is_hostile and body.is_in_group("player"):
		interaction_requested.emit()
