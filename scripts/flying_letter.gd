extends Node2D

## A Hogwarts letter that flies around the dining room during the intro cinematic.
## Bounces off room walls and spins as it flies.

## All rooms in this project are 640 × 480 px; match values in npc.gd.
const _ROOM_WIDTH: float = 640.0
const _ROOM_HEIGHT: float = 480.0
const _WALL_MARGIN: float = 48.0

var _velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	var angle: float = randf_range(0.0, TAU)
	var speed: float = randf_range(60.0, 130.0)
	_velocity = Vector2(cos(angle), sin(angle)) * speed


func _process(delta: float) -> void:
	position += _velocity * delta
	# Gentle spin proportional to horizontal speed
	rotation += delta * sign(_velocity.x) * 1.8

	if position.x < _WALL_MARGIN:
		position.x = _WALL_MARGIN
		_velocity.x = abs(_velocity.x)
	elif position.x > _ROOM_WIDTH - _WALL_MARGIN:
		position.x = _ROOM_WIDTH - _WALL_MARGIN
		_velocity.x = -abs(_velocity.x)

	if position.y < _WALL_MARGIN:
		position.y = _WALL_MARGIN
		_velocity.y = abs(_velocity.y)
	elif position.y > _ROOM_HEIGHT - _WALL_MARGIN:
		position.y = _ROOM_HEIGHT - _WALL_MARGIN
		_velocity.y = -abs(_velocity.y)
