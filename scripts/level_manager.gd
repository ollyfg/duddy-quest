extends Node
## Manages level lifecycle: loading levels, level-end detection, cutscene
## orchestration, room-intro cinematics, and the level-complete overlay.

const _CINEMATIC_PLAYER_SCRIPT: Script = preload("res://scripts/cinematic_player.gd")

var _cinematic_player: Node = null

# ---- External references set by setup() ----
var _levels: Dictionary = {}
var _player = null
var _dialog_box = null
# Callable: (room_name, player_pos) — delegates to room_manager.load_room().
var _load_room: Callable
# current_level_name is readable/writable here and also kept in main.gd.
var current_level_name: String = ""
# Callable: (active: bool) — delegates to dialog_manager.set_dialog_active().
var _set_dialog_active: Callable
# Callable: () -> Node — returns current_room from room_manager.
var _get_current_room: Callable
# Back-reference to main node for add_child and tree operations.
var _main: Node = null
# Callable: (room_name) — from room_manager, used to get pathfinder.
var _get_pathfinder: Callable


func setup(
		p_levels: Dictionary,
		p_player: Node,
		p_dialog_box: Node,
		p_load_room: Callable,
		p_set_dialog_active: Callable,
		p_get_current_room: Callable,
		p_get_pathfinder: Callable,
		p_main: Node) -> void:
	_levels = p_levels
	_player = p_player
	_dialog_box = p_dialog_box
	_load_room = p_load_room
	_set_dialog_active = p_set_dialog_active
	_get_current_room = p_get_current_room
	_get_pathfinder = p_get_pathfinder
	_main = p_main


func load_level(level_name: String) -> void:
	current_level_name = level_name
	if level_name == "level_1":
		_start_level_1_intro()
	else:
		_load_room.call(_levels[level_name]["start_room"], _levels[level_name]["start_pos"])


## Plays the level-1 dining-room intro cinematic then loads the bedroom.
func _start_level_1_intro() -> void:
	await _load_room.call("l1_dining_room", Vector2(448.0, 304.0))
	play_cinematic([
		{"type": "dialog", "speaker": "Vernon", "lines": [
			"Fine day, Sunday. In my opinion, best day of the week. Why is that, Dudley?",
		]},
		{"type": "wait", "duration": 0.8},
		{"type": "dialog", "speaker": "Harry", "lines": [
			"Because there's no post on Sundays?",
		]},
		{"type": "dialog", "speaker": "Vernon", "lines": [
			"Right you are, Harry! No post on Sunday. No blasted letters today! No, sir. Not one single bloody letter. Not one! No, sir, not one blasted, miserable\u2026",
		]},
		{"type": "set_visible", "node": "FlyingLetters", "visible": true},
		{"type": "wait", "duration": 1.2},
		{"type": "dialog", "speaker": "Vernon", "lines": [
			"AAARRRGGHH!",
		]},
		{"type": "dialog", "speaker": "Harry", "lines": [
			"Whoopee!",
		]},
		{"type": "dialog", "speaker": "Vernon", "lines": [
			"GIVE ME THAT LETTER!",
		]},
		{"type": "dialog", "speaker": "", "lines": [
			"Letters everywhere. Hundreds of them. All addressed to POTTER.",
			"But wait. This one says\u2026",
			"'D. DURSLEY (THE LARGER ONE).'",
			"That's ME. Hogwarts wants ME.",
		]},
		{"type": "wait", "duration": 0.5},
	], func():
		_load_room.call(_levels["level_1"]["start_room"], _levels["level_1"]["start_pos"])
	)


func on_level_end_reached(trigger: Node) -> void:
	_player.is_in_dialog = true
	var slides: Array = trigger.end_cutscene_slides
	if slides.is_empty() and current_level_name == "level_1":
		slides = [
			{"image": null, "text": "Dudley boards the number 9 bus.\nIt takes him in completely the wrong direction.", "background_color": Color(0.1, 0.1, 0.1)},
			{"image": null, "text": "The bus deposits him — confusingly — in central London,\noutside a rather grubby pub he could have sworn\nwasn't there yesterday.", "background_color": Color(0.1, 0.1, 0.1)},
		]
	var _do_complete := func(): _show_level_complete(trigger)
	if slides.size() > 0:
		play_cutscene(slides, _do_complete)
	else:
		_do_complete.call()


func on_boss_defeated() -> void:
	_show_level_complete()


func _show_level_complete(trigger: Node = null) -> void:
	GameState.mark_complete(current_level_name)
	var lc_scene: PackedScene = load("res://scenes/level_complete.tscn")
	var lc: Node = lc_scene.instantiate()
	lc.level_title = _levels[current_level_name].get("title", current_level_name)
	_main.add_child(lc)
	lc.continue_pressed.connect(func():
		lc.queue_free()
		var next: String = ""
		if trigger != null and "next_level" in trigger:
			next = trigger.next_level
		if next == "":
			next = _levels[current_level_name].get("next_level", "")
		if next != "" and next in _levels:
			load_level(next)
		else:
			_main.get_tree().change_scene_to_file("res://scenes/level_select.tscn")
	)


func play_cinematic(sequence: Array, on_finish: Callable) -> void:
	if _cinematic_player == null:
		_cinematic_player = Node.new()
		_cinematic_player.set_script(_CINEMATIC_PLAYER_SCRIPT)
		_main.add_child(_cinematic_player)
	if _cinematic_player.has_method("set_pathfinder"):
		_cinematic_player.set_pathfinder(_get_pathfinder.call())
	_cinematic_player.sequence_finished.connect(on_finish, CONNECT_ONE_SHOT)
	_cinematic_player.play(sequence, _get_current_room.call(), _player, _dialog_box)


func play_cutscene(slides: Array, on_finish: Callable) -> void:
	var cutscene_scene: PackedScene = load("res://scenes/cutscene.tscn")
	var cutscene: Node = cutscene_scene.instantiate()
	_main.add_child(cutscene)
	cutscene.cutscene_finished.connect(func():
		on_finish.call()
		cutscene.queue_free()
	)
	cutscene.play(slides)


## First-time intro for the hallway.
func play_hallway_intro() -> void:
	GameState.set_flag("l1_hallway_intro_shown")
	_set_dialog_active.call(true)
	play_cinematic([
		{"type": "pan_camera", "to": Vector2(320.0, 240.0), "duration": 1.2},
		{"type": "dialog", "speaker": "Petunia", "lines": [
			"Breathe. Everything is fine.",
			"A good vacuum, that's what we need.",
			"Everything will be fine if I just keep cleaning.",
		]},
		{"type": "reset_camera", "duration": 0.8},
	], func() -> void: _finish_room_intro())


## First-time intro for the street.
func play_street_intro() -> void:
	GameState.set_flag("l1_street_intro_shown")
	_set_dialog_active.call(true)
	play_cinematic([
		{"type": "pan_camera", "to": Vector2(416.0, 256.0), "duration": 1.2},
		{"type": "dialog", "speaker": "Piers", "lines": [
			"Did you see Dudley sneaking off with that letter?",
			"'Hogwarts School of Witchcraft and Wizardry.' Ha!",
		]},
		{"type": "dialog", "speaker": "Gang Member", "lines": [
			"Witchcraft? Like his cousin Potter?",
		]},
		{"type": "dialog", "speaker": "Piers", "lines": [
			"Looks like Dudders wants to join the freaks.",
			"Can't have that — he'll ruin our reputation.",
			"Teach him a lesson, lads.",
			"Remind him where he belongs.",
		]},
		{"type": "reset_camera", "duration": 0.8},
	], func() -> void: _finish_room_intro())


## Shared cleanup called when any room intro cinematic finishes.
func _finish_room_intro() -> void:
	_set_dialog_active.call(false)
	var current_room: Node = _get_current_room.call()
	if current_room:
		_player.set_camera_limits(current_room.get_room_rect())
