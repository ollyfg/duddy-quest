extends StaticBody2D

## Emitted when the switch is toggled by a melee hit.
signal toggled(switch_id: String, is_on: bool)

## Unique identifier used by the room to find the corresponding door/effect.
@export var id: String = "switch"
## Starting state of the switch.
@export var starts_on: bool = false

var is_on: bool = false

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	is_on = starts_on
	_update_visual()


## Called by the player's melee system when struck.
func on_hit() -> void:
	is_on = not is_on
	_update_visual()
	toggled.emit(id, is_on)


func _update_visual() -> void:
	if is_on:
		sprite.color = Color(0.9, 0.8, 0.1)
	else:
		sprite.color = Color(0.4, 0.4, 0.4)
