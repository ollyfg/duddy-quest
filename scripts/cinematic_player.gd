extends Node

signal sequence_finished

const NavigationUtils = preload("res://scripts/navigation_utils.gd")
## Large limit value used to allow free camera movement during pan steps.
const UNLIMITED_CAMERA_LIMIT: int = GameConfig.UNLIMITED_CAMERA_LIMIT

## All recognised cinematic step type strings.
const KNOWN_STEP_TYPES: Array[String] = [
	"move_npc", "move_player", "dialog", "set_visible",
	"wait", "play_cutscene", "pan_camera", "reset_camera",
]

## Keys that must be present for each step type.
const STEP_REQUIRED_KEYS: Dictionary = {
	"move_npc": ["npc", "to"],
	"move_player": ["to"],
	"set_visible": ["node"],
	"pan_camera": ["to"],
}

var _room: Node = null
var _player: Node = null
var _dialog_box: Node = null
var _is_playing: bool = false
## A* pathfinder for the current room; null when not available.
var _pathfinder = null


## Returns true while a cinematic sequence is actively playing.
func is_playing() -> bool:
	return _is_playing


func set_pathfinder(pf) -> void:
	_pathfinder = pf


func play(sequence: Array, room: Node, player: Node, dialog_box: Node = null) -> void:
	_room = room
	_player = player
	_dialog_box = dialog_box
	_is_playing = true
	if OS.is_debug_build():
		for step: Dictionary in sequence:
			_validate_step(step)
	player.cinematic_mode = true
	await _run_sequence(sequence)
	player.cinematic_mode = false
	_is_playing = false
	sequence_finished.emit()


## Validate a cinematic step dictionary in debug builds.
## Returns true if the step is well-formed, false and logs a warning/error otherwise.
static func _validate_step(step: Dictionary) -> bool:
	var type: String = step.get("type", "")
	if not type in KNOWN_STEP_TYPES:
		push_warning("Unknown cinematic step type: '%s'" % type)
		return false
	var required: Array = STEP_REQUIRED_KEYS.get(type, [])
	var ok: bool = true
	for key: String in required:
		if not step.has(key):
			push_error("Cinematic step '%s' is missing required key '%s'" % [type, key])
			ok = false
	return ok


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
				if _dialog_box.has_method("set_speaker"):
					_dialog_box.set_speaker(step.get("speaker", ""))
				_dialog_box.start_dialog(step.get("lines", []))
				await _dialog_box.dialog_ended
		"set_visible":
			var vis_node: Node = _room.get_node_or_null(step.get("node", ""))
			if vis_node:
				vis_node.visible = step.get("visible", true)
			else:
				push_warning("cinematic set_visible: node not found: %s" % step.get("node", ""))
		"wait":
			await get_tree().create_timer(step.get("duration", 1.0)).timeout
		"play_cutscene":
			if _player.get_parent().has_method("play_cutscene"):
				var done: bool = false
				_player.get_parent().play_cutscene(step.get("slides", []), func() -> void: done = true)
				while not done:
					await get_tree().process_frame
		"pan_camera":
			var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
			if cam:
				cam.position_smoothing_enabled = false
				# Expand limits so the camera can pan freely within the room.
				cam.limit_left = -UNLIMITED_CAMERA_LIMIT
				cam.limit_top = -UNLIMITED_CAMERA_LIMIT
				cam.limit_right = UNLIMITED_CAMERA_LIMIT
				cam.limit_bottom = UNLIMITED_CAMERA_LIMIT
				var target_offset: Vector2 = step["to"] - _player.global_position
				var duration: float = step.get("duration", 1.0)
				var tween: Tween = cam.create_tween()
				tween.tween_property(cam, "offset", target_offset, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				await tween.finished
		"reset_camera":
			var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
			if cam:
				var duration: float = step.get("duration", 1.0)
				var tween: Tween = cam.create_tween()
				tween.tween_property(cam, "offset", Vector2.ZERO, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				await tween.finished
				cam.position_smoothing_enabled = true


func _move_node(node: Node2D, target: Vector2, speed: float) -> void:
	while node.global_position.distance_to(target) > 4.0:
		var dir: Vector2
		if node is CharacterBody2D:
			if _pathfinder != null:
				dir = _pathfinder.get_next_direction(node.global_position, target)
			else:
				var body: CharacterBody2D = node as CharacterBody2D
				var space: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
				dir = NavigationUtils.navigate_toward(
					body.global_position,
					target,
					space,
					[body.get_rid()]
				)
		else:
			dir = (target - node.global_position).normalized()
		node.velocity = dir * speed
		node.move_and_slide()
		await get_tree().process_frame
	node.global_position = target
	node.velocity = Vector2.ZERO
