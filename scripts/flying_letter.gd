extends Node2D

## A Hogwarts letter that flies around the dining room during the intro cinematic.
## Bounces off room walls and spins as it flies.

const _WALL_MARGIN: float = 48.0

## Base launch angle in radians.  When >= 0 the letter flies in this direction
## (plus a small random variation) — useful for spawning from a wall with a
## direction normal to that wall.  When negative a fully random direction is
## chosen.
@export var spawn_velocity_angle: float = -1.0

var _velocity: Vector2 = Vector2.ZERO
var _room_width: float = 0.0
var _room_height: float = 0.0


func _ready() -> void:
	# Read room size from the parent room node; fall back to viewport size.
	var parent: Node = get_parent()
	if parent and parent.has_method("get_room_rect"):
		var rect: Rect2 = parent.get_room_rect()
		_room_width = rect.size.x
		_room_height = rect.size.y
	else:
		var vp_size: Vector2 = get_viewport_rect().size
		_room_width = vp_size.x
		_room_height = vp_size.y

	var angle: float
	if spawn_velocity_angle >= 0.0:
		# Normal to the spawn wall plus a small random variation (±0.25 rad ≈ ±14.3°).
		angle = spawn_velocity_angle + randf_range(-0.25, 0.25)
	else:
		angle = randf_range(0.0, TAU)
	var speed: float = randf_range(60.0, 130.0)
	_velocity = Vector2(cos(angle), sin(angle)) * speed


func _process(delta: float) -> void:
	position += _velocity * delta
	# Gentle spin proportional to horizontal speed
	rotation += delta * sign(_velocity.x) * 1.8

	if position.x < _WALL_MARGIN:
		position.x = _WALL_MARGIN
		_velocity.x = abs(_velocity.x)
	elif position.x > _room_width - _WALL_MARGIN:
		position.x = _room_width - _WALL_MARGIN
		_velocity.x = -abs(_velocity.x)

	if position.y < _WALL_MARGIN:
		position.y = _WALL_MARGIN
		_velocity.y = abs(_velocity.y)
	elif position.y > _room_height - _WALL_MARGIN:
		position.y = _room_height - _WALL_MARGIN
		_velocity.y = -abs(_velocity.y)
