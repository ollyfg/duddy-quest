extends CharacterBody2D

signal pushed(new_position: Vector2)

const GRID_SIZE: int = 16
const PUSH_FRAMES: float = 60.0

@export var sprite_color: Color = Color(0.6, 0.6, 0.6)
@export var push_sound: AudioStream = null
@export var piece_type: String = "free"

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	add_to_group("pushable")
	sprite.color = sprite_color


func try_push(direction: Vector2) -> bool:
	var is_horizontal: bool = abs(direction.x) > abs(direction.y)
	var is_diagonal: bool = abs(direction.x) > 0.1 and abs(direction.y) > 0.1

	match piece_type:
		"rook":
			if is_diagonal:
				return false
		"bishop":
			if not is_diagonal:
				return false

	var snap_dir := Vector2(sign(direction.x), sign(direction.y)).normalized()
	var target := global_position + snap_dir * GRID_SIZE

	var before := global_position
	velocity = snap_dir * GRID_SIZE * PUSH_FRAMES
	move_and_slide()
	velocity = Vector2.ZERO

	if global_position.distance_to(before) < 1.0:
		return false

	global_position = target
	pushed.emit(global_position)
	return true


func get_grid_position() -> Vector2i:
	return Vector2i(int(global_position.x) / GRID_SIZE, int(global_position.y) / GRID_SIZE)
