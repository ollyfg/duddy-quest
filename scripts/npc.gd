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
enum MovementMode { DEFAULT, STATIONARY, WANDER, CHASE, KEEP_DISTANCE, JOSTLING }
@export var movement_mode: MovementMode = MovementMode.DEFAULT

## Preferred stand-off distance used by the KEEP_DISTANCE mode.
@export var keep_distance_preferred: float = 180.0

signal interaction_requested

const KNOCKBACK_SPEED: float = 250.0
## Distance within which JOSTLING replaces straight chasing.
const JOSTLE_RANGE: float = 150.0
## Inner and outer bounds for KEEP_DISTANCE mode.
const KEEP_DIST_MARGIN: float = 50.0

var hp: int
var is_paused: bool = false
var _wander_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _player_ref: Node = null
var _knockback_velocity: Vector2 = Vector2.ZERO
var _jostle_timer: float = 0.0

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
	if is_paused:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var mode: MovementMode = movement_mode
	if mode == MovementMode.DEFAULT:
		mode = MovementMode.CHASE if is_hostile else MovementMode.WANDER

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
		MovementMode.JOSTLING:
			if _player_ref:
				_jostle(delta)
			else:
				velocity = Vector2.ZERO

	velocity += _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_SPEED * delta * 6.0)

	move_and_slide()


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
			var angle: float = randf() * TAU
			_wander_dir = Vector2(cos(angle), sin(angle))
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


## Circles and hops around the player in close combat, changing direction
## frequently to be unpredictable.  Chases normally when far away.
func _jostle(delta: float) -> void:
	var to_player: Vector2 = _player_ref.global_position - global_position
	var dist: float = to_player.length()
	_jostle_timer -= delta
	if dist > JOSTLE_RANGE:
		# Close the gap first.
		velocity = to_player.normalized() * move_speed
	elif _jostle_timer <= 0.0:
		_jostle_timer = randf_range(0.2, 0.55)
		# Blend a perpendicular (circling) component with a small advance/retreat.
		var perp: Vector2 = Vector2(-to_player.y, to_player.x).normalized()
		if randf() < 0.5:
			perp = -perp
		var forward_bias: float = randf_range(-0.3, 0.5)
		velocity = (perp + to_player.normalized() * forward_bias).normalized() * move_speed


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()


func apply_knockback(direction: Vector2) -> void:
	_knockback_velocity = direction.normalized() * KNOCKBACK_SPEED


func _on_hit_area_body_entered(body: Node) -> void:
	if is_hostile and body.is_in_group("player"):
		var direction: Vector2 = ((body as Node2D).global_position - global_position).normalized()
		body.take_damage(1)
		body.apply_knockback(direction)
	elif not is_hostile and body.is_in_group("player"):
		interaction_requested.emit()
