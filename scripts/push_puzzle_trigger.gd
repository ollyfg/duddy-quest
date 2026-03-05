extends Node2D

signal puzzle_solved

@export var required_blocks: Array[NodePath]
@export var required_positions: Array[Vector2]

var _solved: bool = false


func _ready() -> void:
	for path in required_blocks:
		var block := get_node_or_null(path)
		if block and block.has_signal("pushed"):
			block.pushed.connect(_on_block_pushed)


func _on_block_pushed(_new_pos: Vector2) -> void:
	_check_solved()


func _check_solved() -> void:
	if _solved:
		return
	if required_blocks.size() != required_positions.size() or required_blocks.is_empty():
		return

	for i: int in range(required_blocks.size()):
		var block := get_node_or_null(required_blocks[i])
		if block == null:
			return
		var block_pos: Vector2 = (block as Node2D).global_position
		if block_pos.distance_to(required_positions[i]) > 4.0:
			return

	_solved = true
	puzzle_solved.emit()
