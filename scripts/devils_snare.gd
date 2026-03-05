extends Area2D

@export var open_exit_on_clear: bool = false

var _is_open: bool = false
var _tween: Tween = null

@onready var sprite: ColorRect = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	sprite.color = Color(0.1, 0.5, 0.1, 0.8)


func _physics_process(_delta: float) -> void:
	var should_open: bool = LightSource.is_point_lit(global_position, get_tree())
	if should_open and not _is_open:
		_open()
	elif not should_open and _is_open:
		_close()


func _open() -> void:
	_is_open = true
	collision.set_deferred("disabled", true)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)


func _close() -> void:
	_is_open = false
	collision.set_deferred("disabled", false)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(sprite, "modulate:a", 1.0, 0.3)
