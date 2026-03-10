extends StaticBody2D

## Seconds between each rotation toggle.
@export var rotation_interval: float = 1.5

## Initial delay before the first toggle.  Stagger this value on each
## mannequin instance so they do not all rotate in sync.
@export var start_offset: float = 0.0

## Whether the arm currently blocks passage (collision enabled).
var _blocking: bool = true

@onready var _arm_shape: CollisionShape2D = $ArmShape
@onready var _sprite: ColorRect = $Sprite


func _ready() -> void:
	_apply_state()
	if start_offset > 0.0:
		await get_tree().create_timer(start_offset).timeout
	var timer := Timer.new()
	timer.wait_time = rotation_interval
	timer.autostart = true
	timer.timeout.connect(_toggle)
	add_child(timer)


func _toggle() -> void:
	_blocking = not _blocking
	_apply_state()


func _apply_state() -> void:
	_arm_shape.set_deferred("disabled", not _blocking)
	if _blocking:
		_sprite.color = Color(0.7, 0.6, 0.5, 1.0)
	else:
		_sprite.color = Color(0.5, 0.45, 0.4, 0.4)
