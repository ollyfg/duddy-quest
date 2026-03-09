extends Node
## Manages level lifecycle: loading, intro cinematics, level-end cutscenes,
## boss defeat, and the level-complete screen.

## Reference to main.gd for LEVELS, current_level_name, play_cinematic, etc.
var _main: Node


func setup(main: Node) -> void:
	_main = main


func load_level(level_name: String) -> void:
	_main.current_level_name = level_name
	_main.room_manager.clear_room_states()
	if level_name == "level_1":
		_start_level_1_intro()
	else:
		var level: Dictionary = _main.LEVELS[level_name]
		_main.room_manager.load_room(level["start_room"], level["start_pos"])


## Plays the level-1 dining-room intro cinematic then loads the bedroom.
func _start_level_1_intro() -> void:
	await _main.room_manager.load_room("l1_dining_room", Vector2(448.0, 304.0))
	_main.play_cinematic([
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
		_main.room_manager.load_room(_main.LEVELS["level_1"]["start_room"], _main.LEVELS["level_1"]["start_pos"])
	)


func _on_level_end_reached(trigger: Node) -> void:
	_main.player.is_in_dialog = true
	var slides: Array = trigger.end_cutscene_slides
	# Level-specific end cutscenes (defined here because Dictionaries with Color
	# values cannot be serialised directly in .tscn property overrides).
	if slides.is_empty() and _main.current_level_name == "level_1":
		slides = [
			{"image": null, "text": "Dudley boards the number 9 bus.\nIt takes him in completely the wrong direction.", "background_color": Color(0.1, 0.1, 0.1)},
			{"image": null, "text": "The bus deposits him — confusingly — in central London,\noutside a rather grubby pub he could have sworn\nwasn't there yesterday.", "background_color": Color(0.1, 0.1, 0.1)},
		]
	var _do_complete := func(): _show_level_complete(trigger)
	if slides.size() > 0:
		_main.play_cutscene(slides, _do_complete)
	else:
		_do_complete.call()


func _on_boss_defeated() -> void:
	_show_level_complete()


func _show_level_complete(trigger: Node = null) -> void:
	GameState.mark_complete(_main.current_level_name)
	var lc_scene: PackedScene = load("res://scenes/level_complete.tscn")
	var lc: Node = lc_scene.instantiate()
	lc.level_title = _main.LEVELS[_main.current_level_name].get("title", _main.current_level_name)
	_main.add_child(lc)
	lc.continue_pressed.connect(func():
		lc.queue_free()
		var next: String = ""
		if trigger != null and "next_level" in trigger:
			next = trigger.next_level
		if next == "":
			next = _main.LEVELS[_main.current_level_name].get("next_level", "")
		if next != "" and next in _main.LEVELS:
			load_level(next)
		else:
			get_tree().change_scene_to_file("res://scenes/level_select.tscn")
	)
