extends Area2D

## Types of items the player can pick up.
enum ItemType { HEALTH, WAND, KEY }

@export var item_type: ItemType = ItemType.HEALTH
## How many HP to restore when item_type is HEALTH.
@export var heal_amount: int = 2
## Unique identifier used to match this key with locked exits/doors.
@export var key_id: String = "key_default"

## Optional GameState flag to set when this item is picked up.
## Useful for KEY items that need to trigger story progression.
@export var set_flag_on_pickup: String = ""

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	match item_type:
		ItemType.HEALTH:
			sprite.color = Color(0.9, 0.1, 0.1)
		ItemType.WAND:
			sprite.color = Color(0.7, 0.1, 0.9)
		ItemType.KEY:
			sprite.color = Color(0.95, 0.85, 0.1)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.has_method("collect_item"):
		var type_str: String
		match item_type:
			ItemType.HEALTH: type_str = "health"
			ItemType.WAND:   type_str = "wand"
			ItemType.KEY:    type_str = "key"
		body.collect_item(type_str, {"amount": heal_amount, "key_id": key_id})
		if set_flag_on_pickup != "":
			GameState.set_flag(set_flag_on_pickup)
		queue_free()
