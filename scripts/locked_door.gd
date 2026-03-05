extends StaticBody2D

signal door_opened(key_id: String)

@export var required_key: String = "key_default"

@onready var sprite: ColorRect = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D

var _is_open: bool = false


func _ready() -> void:
	add_to_group("locked_doors")


func _physics_process(_delta: float) -> void:
	if _is_open:
		return
	# Check for adjacent player pressing interact.
	if Input.is_action_just_pressed("interact"):
		var player := _get_adjacent_player()
		if player and player.has_key(required_key):
			_open(player)


func _get_adjacent_player() -> Node:
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	(query.shape as RectangleShape2D).size = Vector2(48.0, 48.0)
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2  # Player layer
	var results := space.intersect_shape(query)
	for r in results:
		if r["collider"].is_in_group("player"):
			return r["collider"]
	return null


func _open(player: Node) -> void:
	_is_open = true
	player.remove_key(required_key)
	sprite.visible = false
	collision.set_deferred("disabled", true)
	door_opened.emit(required_key)
