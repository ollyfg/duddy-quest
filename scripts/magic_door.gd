extends StaticBody2D

signal door_opened

@export var requires_frustration_enabled: bool = true

@onready var sprite: ColorRect = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("accidental_magic_target")


func on_accidental_magic() -> void:
	if requires_frustration_enabled:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if players.is_empty():
			return
		var player: Node = players[0]
		if not player.frustration_enabled:
			return
	_open()


func _open() -> void:
	door_opened.emit()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		collision.set_deferred("disabled", true)
		visible = false
	)
