extends Node

signal sequence_finished

var _room: Node = null
var _player: Node = null
var _dialog_box: Node = null
var _is_playing: bool = false


func play(sequence: Array, room: Node, player: Node, dialog_box: Node = null) -> void:
	_room = room
	_player = player
	_dialog_box = dialog_box
	_is_playing = true
	player.cinematic_mode = true
	await _run_sequence(sequence)
	player.cinematic_mode = false
	_is_playing = false
	sequence_finished.emit()


func _run_sequence(steps: Array) -> void:
	var i: int = 0
	while i < steps.size():
		var step: Dictionary = steps[i]
		if not step.get("parallel", false):
			await _run_step(step)
			i += 1
		else:
			# Collect all "parallel: true" steps plus the first non-parallel terminator.
			var group: Array = []
			while i < steps.size() and steps[i].get("parallel", false):
				group.append(steps[i])
				i += 1
			if i < steps.size():
				group.append(steps[i])
				i += 1
			# GDScript has no true coroutine parallelism; run sequentially.
			for ps: Dictionary in group:
				await _run_step(ps)


func _run_step(step: Dictionary) -> void:
	match step.get("type", ""):
		"move_npc":
			var npc: Node = _room.get_node_or_null(step["npc"])
			if npc:
				npc.is_paused = true
				await _move_node(npc, step["to"], step.get("speed", 80.0))
		"move_player":
			await _move_node(_player, step["to"], step.get("speed", 150.0))
		"dialog":
			if _dialog_box:
				_dialog_box.start_dialog(step.get("lines", []))
				await _dialog_box.dialog_ended
		"wait":
			await get_tree().create_timer(step.get("duration", 1.0)).timeout
		"play_cutscene":
			if _player.get_parent().has_method("play_cutscene"):
				var done: bool = false
				_player.get_parent().play_cutscene(step.get("slides", []), func() -> void: done = true)
				while not done:
					await get_tree().process_frame


func _move_node(node: Node2D, target: Vector2, speed: float) -> void:
	while node.global_position.distance_to(target) > 4.0:
		var dir: Vector2
		if node is CharacterBody2D:
			dir = _navigate_node_toward(node as CharacterBody2D, target)
		else:
			dir = (target - node.global_position).normalized()
		node.velocity = dir * speed
		node.move_and_slide()
		await get_tree().process_frame
	node.global_position = target
	node.velocity = Vector2.ZERO


## Returns the best direction to steer `node` toward `target` while avoiding
## static obstacles (walls, furniture).  Uses the same short-range raycast
## context-steering algorithm as npc.gd's _navigate_toward().
func _navigate_node_toward(node: CharacterBody2D, target: Vector2) -> Vector2:
	var to_target: Vector2 = target - node.global_position
	if to_target.length_squared() < 1.0:
		return Vector2.ZERO
	var desired_dir: Vector2 = to_target.normalized()

	const LOOK_AHEAD: float = 40.0
	var space: PhysicsDirectSpaceState2D = node.get_world_2d().direct_space_state

	var excl: Array[RID] = [node.get_rid()]
	var q := PhysicsRayQueryParameters2D.create(
		node.global_position, node.global_position + desired_dir * LOOK_AHEAD)
	q.exclude = excl
	if space.intersect_ray(q).is_empty():
		return desired_dir

	# Direct path blocked — try progressively wider angles on both sides.
	var steer_angles: Array[int] = [30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180]
	var best_dir: Vector2 = desired_dir
	var best_score: float = -INF
	for angle_deg: int in steer_angles:
		var test_dir: Vector2 = desired_dir.rotated(deg_to_rad(float(angle_deg)))
		var qt := PhysicsRayQueryParameters2D.create(
			node.global_position, node.global_position + test_dir * LOOK_AHEAD)
		qt.exclude = excl
		if space.intersect_ray(qt).is_empty():
			var score: float = test_dir.dot(desired_dir)
			if score > best_score:
				best_score = score
				best_dir = test_dir
	return best_dir
