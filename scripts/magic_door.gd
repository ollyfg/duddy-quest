extends StaticBody2D

signal door_opened

@onready var sprite: ColorRect = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("breakable")


func on_rage_attack() -> void:
	_open()


func _open() -> void:
	door_opened.emit()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		collision.set_deferred("disabled", true)
		visible = false
	)
