extends Area2D

signal level_end_reached

@export var end_cutscene_slides: Array = []
@export var next_level: String = ""


func _ready() -> void:
	add_to_group("level_end")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		level_end_reached.emit()
