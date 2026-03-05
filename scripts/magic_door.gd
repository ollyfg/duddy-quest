extends StaticBody2D

signal door_opened
## Emitted the first time a player body enters the hint detection area.
signal door_approached

@onready var sprite: ColorRect = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("breakable")
	if has_node("HintArea"):
		get_node("HintArea").body_entered.connect(_on_hint_area_body_entered)


func _on_hint_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		door_approached.emit()
		# Disconnect so the signal fires at most once per room visit.
		get_node("HintArea").body_entered.disconnect(_on_hint_area_body_entered)


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
