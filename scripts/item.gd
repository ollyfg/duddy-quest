extends Area2D

## Types of items the player can pick up.
enum ItemType { HEALTH, WAND }

@export var item_type: ItemType = ItemType.HEALTH
## How many HP to restore when item_type is HEALTH.
@export var heal_amount: int = 2

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	match item_type:
		ItemType.HEALTH:
			sprite.color = Color(0.9, 0.1, 0.1)
		ItemType.WAND:
			sprite.color = Color(0.7, 0.1, 0.9)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_pickup(body)


func _pickup(player: Node) -> void:
	match item_type:
		ItemType.HEALTH:
			player.hp += heal_amount
		ItemType.WAND:
			player.has_wand = true
	queue_free()
