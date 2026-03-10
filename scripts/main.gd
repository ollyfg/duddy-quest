extends Node2D

## Level metadata loaded at runtime from data/*.json.
## Each entry maps level_name -> { title, next_level, start_room, start_pos,
##   rooms: {name -> "res://..." path}, connections: {name -> {dir -> {room, entry}}} }
var LEVELS: Dictionary = {}


func _init() -> void:
	_load_all_levels()


## Populate LEVELS by reading every data/*.json file.
## Vector2 values are restored from [x, y] arrays stored in JSON.
func _load_all_levels() -> void:
	var dir := DirAccess.open("res://data")
	if dir == null:
		push_error("main.gd: could not open res://data/")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			_load_level_file("res://data/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _load_level_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("main.gd: could not open level file: " + path)
		return
	var json_text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		push_error("main.gd: failed to parse JSON from: " + path)
		return
	var data: Dictionary = parsed as Dictionary
	# Derive the level key from the filename (e.g. "level_1.json" -> "level_1").
	var level_name: String = path.get_file().get_basename()
	# Convert start_pos [x, y] array to Vector2.
	var sp: Variant = data.get("start_pos", [0.0, 0.0])
	if sp is Array and (sp as Array).size() >= 2:
		data["start_pos"] = Vector2(sp[0], sp[1])
	else:
		push_error("main.gd: invalid start_pos in: " + path)
		return
	# Convert each connection entry [x, y] array to Vector2.
	for room_conns: Variant in data.get("connections", {}).values():
		if not room_conns is Dictionary:
			push_error("main.gd: invalid connections entry in: " + path)
			return
		for conn: Variant in (room_conns as Dictionary).values():
			if not conn is Dictionary:
				push_error("main.gd: invalid connection data in: " + path)
				return
			var e: Variant = (conn as Dictionary).get("entry", [0.0, 0.0])
			if e is Array and (e as Array).size() >= 2:
				(conn as Dictionary)["entry"] = Vector2(e[0], e[1])
			else:
				push_error("main.gd: invalid entry coords in: " + path)
				return
	LEVELS[level_name] = data

var current_level_name: String = ""

@onready var room_holder: Node2D = $RoomHolder
# Untyped to allow accessing player.gd custom signals and properties.
@onready var player = $Player
# Untyped to allow calling dialog_box.gd methods (is_active, start_dialog).
@onready var dialog_box = $HUD/DialogBox
@onready var hp_bar: HBoxContainer = $HUD/HPBar
@onready var key_label: Label = $HUD/KeyLabel
@onready var rage_bar: ProgressBar = $HUD/RageBar
@onready var mobile_controls = $MobileControls

## Child-node managers — created in _ready() and kept as typed references so
## other managers can reach them via main.hud_manager / main.room_manager etc.
var hud_manager: Node = null
var dialog_manager: Node = null
var room_manager: Node = null
var level_manager: Node = null

var _cinematic_player: Node = null
const _CINEMATIC_PLAYER_SCRIPT: Script = preload("res://scripts/cinematic_player.gd")


func _ready() -> void:
	player.add_to_group("player")

	# Instantiate managers as child nodes and wire them up.
	hud_manager = Node.new()
	hud_manager.set_script(preload("res://scripts/hud_manager.gd"))
	add_child(hud_manager)
	hud_manager.setup(player, hp_bar, key_label, rage_bar, mobile_controls)

	dialog_manager = Node.new()
	dialog_manager.set_script(preload("res://scripts/dialog_manager.gd"))
	add_child(dialog_manager)
	dialog_manager.setup(player, dialog_box, self)

	room_manager = Node.new()
	room_manager.set_script(preload("res://scripts/room_manager.gd"))
	add_child(room_manager)
	room_manager.setup(player, room_holder, self)

	level_manager = Node.new()
	level_manager.set_script(preload("res://scripts/level_manager.gd"))
	add_child(level_manager)
	level_manager.setup(self)

	# Allow launching into a specific level via --level <name> CLI argument;
	# otherwise use the level chosen on the level-select screen.
	var args := OS.get_cmdline_user_args()
	# Fall back to level_1 if the stored level is missing from LEVELS.
	var level_name: String = GameState.selected_level if GameState.selected_level in LEVELS else "level_1"
	var idx := args.find("--level")
	if idx >= 0:
		if idx + 1 < args.size():
			var requested: String = args[idx + 1]
			if requested in LEVELS:
				level_name = requested
			else:
				push_warning("Unknown level '%s', falling back to '%s'." % [requested, level_name])
		else:
			push_warning("--level flag provided without a value, using '%s'." % level_name)

	level_manager.load_level(level_name)


func play_cinematic(sequence: Array, on_finish: Callable) -> void:
	if _cinematic_player == null:
		_cinematic_player = Node.new()
		_cinematic_player.set_script(_CINEMATIC_PLAYER_SCRIPT)
		add_child(_cinematic_player)
	# Pass the current room's A* pathfinder so cinematic movement navigates
	# around furniture correctly.
	if _cinematic_player.has_method("set_pathfinder"):
		_cinematic_player.set_pathfinder(room_manager.get_pathfinder())
	_cinematic_player.sequence_finished.connect(on_finish, CONNECT_ONE_SHOT)
	_cinematic_player.play(sequence, room_manager.current_room, player, dialog_box)


## Returns true if a cinematic sequence is currently playing.
## Used by room_manager to detect first-visit intro conflicts during transitions.
func is_cinematic_playing() -> bool:
	return _cinematic_player != null and _cinematic_player.is_playing()


func play_cutscene(slides: Array, on_finish: Callable) -> void:
	var cutscene_scene: PackedScene = load("res://scenes/cutscene.tscn")
	var cutscene: Node = cutscene_scene.instantiate()
	add_child(cutscene)
	cutscene.cutscene_finished.connect(func():
		on_finish.call()
		cutscene.queue_free()
	)
	cutscene.play(slides)


## First-time intro for the hallway: Petunia paces while muttering to herself.
func _play_hallway_intro() -> void:
	GameState.set_flag("l1_hallway_intro_shown")
	dialog_manager.set_dialog_active(true)
	play_cinematic([
		{"type": "pan_camera", "to": Vector2(320.0, 240.0), "duration": 1.2},
		{"type": "dialog", "speaker": "Petunia", "lines": [
			"Breathe. Everything is fine.",
			"A good vacuum, that's what we need.",
			"Everything will be fine if I just keep cleaning.",
		]},
		{"type": "reset_camera", "duration": 0.8},
	], func() -> void: _finish_room_intro())


## First-time intro for the street: Piers and his gang scheme against Dudley.
func _play_street_intro() -> void:
	GameState.set_flag("l1_street_intro_shown")
	dialog_manager.set_dialog_active(true)
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
	dialog_manager.set_dialog_active(false)
	player.set_camera_limits(room_manager.current_room.get_room_rect())


## First-time intro for the Leaky Cauldron: Tom greets Dudley and explains Diagon Alley.
func _play_leaky_cauldron_intro() -> void:
	GameState.set_flag("l2_leaky_cauldron_intro_shown")
	dialog_manager.set_dialog_active(true)
	play_cinematic([
		{"type": "dialog", "speaker": "Tom", "lines": [
			"Welcome to the Leaky Cauldron, lad!",
			"Through that wall is Diagon Alley. Best place for school supplies.",
			"You'll want Gringotts for your money, then the shops.",
		]},
	], func() -> void: _finish_room_intro())


## Called when the player interacts with Mr Ollivander.
## Plays the wand-choosing cinematic on first visit; shows repeat dialog after.
func _on_ollivander_interaction_requested() -> void:
	if dialog_box.is_active():
		return
	if not GameState.has_flag("l2_wand_acquired"):
		dialog_manager.set_dialog_active(true)
		_play_ollivander_wand_cinematic()
	else:
		dialog_manager.set_dialog_active(true)
		dialog_box.set_speaker("Mr Ollivander")
		dialog_box.start_dialog(["Take care of that wand, boy. It chose you."])


## Wand-choosing cinematic for Ollivander's shop.
func _play_ollivander_wand_cinematic() -> void:
	var rp: Vector2 = room_manager.current_room.global_position
	var shelf_pos: Vector2 = rp + Vector2(530.0, 160.0)
	play_cinematic([
		{"type": "dialog", "speaker": "Mr Ollivander", "lines": [
			"Hmm... a Muggle-born, are you? Most unusual.",
		]},
		{"type": "move_npc", "npc": "NPCs/Ollivander", "to": shelf_pos, "speed": 50.0},
		{"type": "wait", "duration": 0.5},
		{"type": "dialog", "speaker": "Mr Ollivander", "lines": [
			"Maple and unicorn tail-hair. Eight and three-quarter inches. Quite inflexible.",
		]},
		{"type": "dialog", "speaker": "Mr Ollivander", "lines": [
			"Rather like its new owner, I suspect.",
		]},
		{"type": "flash", "color": Color(1.0, 0.85, 0.0, 0.7)},
		{"type": "dialog", "speaker": "Mr Ollivander", "lines": [
			"A promising start.",
		]},
	], func() -> void:
		player.has_wand = true
		GameState.set_flag("l2_has_wand")
		GameState.set_flag("l2_wand_acquired")
		dialog_manager.set_dialog_active(false)
	)


## Intro cinematic for the Draco fight in l2_alley_end.
func _play_draco_intro_cinematic() -> void:
	GameState.set_flag("l2_draco_fight_intro_shown")
	dialog_manager.set_dialog_active(true)
	play_cinematic([
		{"type": "pan_camera", "to": Vector2(320.0, 280.0), "duration": 1.0},
		{"type": "dialog", "speaker": "Draco", "lines": [
			"Well, well. A Muggle at Hogwarts. How revolting.",
		]},
		{"type": "dialog", "speaker": "Draco", "lines": [
			"Father's cane has a few tricks. Let me show you.",
		]},
		{"type": "reset_camera", "duration": 0.8},
	], func() -> void: _finish_room_intro())


## Defeat cinematic for Draco: he flees north, Lucius follows.
func _play_draco_defeat_cinematic() -> void:
	var room: Node = room_manager.current_room
	var rp: Vector2 = room.global_position
	var draco_node: Node = room.get_node_or_null("NPCs/Draco")
	var lucius_node: Node = room.get_node_or_null("NPCs/Lucius")
	dialog_manager.set_dialog_active(true)
	play_cinematic([
		{"type": "dialog", "speaker": "Draco", "lines": [
			"My father will hear about this!",
		]},
		{"type": "move_npc", "npc": "NPCs/Draco", "to": rp + Vector2(320.0, 32.0), "speed": 80.0},
		{"type": "set_visible", "node": "NPCs/Draco", "visible": false},
		{"type": "wait", "duration": 0.3},
		{"type": "move_npc", "npc": "NPCs/Lucius", "to": rp + Vector2(200.0, 32.0), "speed": 60.0},
		{"type": "set_visible", "node": "NPCs/Lucius", "visible": false},
	], func() -> void:
		if draco_node != null and is_instance_valid(draco_node):
			draco_node.queue_free()
		if lucius_node != null and is_instance_valid(lucius_node):
			lucius_node.queue_free()
		GameState.set_flag("l2_draco_defeated")
		dialog_manager.set_dialog_active(false)
	)


## Delegates a screen flash to the HUD manager (called by cinematic_player).
func _do_cinematic_flash(flash_color: Color, duration: float) -> void:
	hud_manager.play_flash(flash_color, duration)


## Called when any wizard patron in the Leaky Cauldron takes damage.
## Triggers the bar fight cinematic once.
func _on_patron_damaged() -> void:
	if GameState.has_flag("l2_bar_fight_triggered"):
		return
	if is_cinematic_playing() or dialog_box.is_active():
		return
	GameState.set_flag("l2_bar_fight_triggered")
	# Make all patrons invincible so they survive the cinematic.
	for npc in room_manager.current_room.get_npcs():
		if npc.name.begins_with("Patron"):
			npc.invincible = true
	_play_bar_fight_cinematic()


## Bar fight cinematic: the wizard patrons brawl while Tom tells Dudley to stay back.
func _play_bar_fight_cinematic() -> void:
	var room: Node = room_manager.current_room
	var rp: Vector2 = room.global_position
	dialog_manager.set_dialog_active(true)
	play_cinematic([
		{"type": "dialog", "speaker": "Tom", "lines": [
			"Oi! Stay back, lad! Don't get in the middle of this!",
		]},
		{"type": "move_npc", "npc": "NPCs/Patron1", "to": rp + Vector2(250.0, 300.0), "speed": 120.0},
		{"type": "move_npc", "npc": "NPCs/Patron2", "to": rp + Vector2(280.0, 320.0), "speed": 120.0},
		{"type": "flash", "color": Color(1.0, 0.3, 0.3, 0.6), "duration": 0.2},
		{"type": "move_npc", "npc": "NPCs/Patron3", "to": rp + Vector2(260.0, 280.0), "speed": 100.0},
		{"type": "flash", "color": Color(1.0, 0.3, 0.3, 0.6), "duration": 0.2},
		{"type": "wait", "duration": 0.3},
		{"type": "move_npc", "npc": "NPCs/Patron1", "to": rp + Vector2(350.0, 350.0), "speed": 140.0},
		{"type": "flash", "color": Color(1.0, 0.2, 0.2, 0.7), "duration": 0.2},
		{"type": "move_npc", "npc": "NPCs/Patron2", "to": rp + Vector2(180.0, 300.0), "speed": 130.0},
		{"type": "move_npc", "npc": "NPCs/Patron3", "to": rp + Vector2(320.0, 340.0), "speed": 110.0},
		{"type": "flash", "color": Color(1.0, 0.2, 0.2, 0.7), "duration": 0.2},
		{"type": "wait", "duration": 0.5},
		{"type": "dialog", "speaker": "Tom", "lines": [
			"*sigh* Every blessed time...",
			"Right, you lot — OUT! I just mopped these floors!",
		]},
		{"type": "set_visible", "node": "NPCs/Patron1", "visible": false},
		{"type": "set_visible", "node": "NPCs/Patron2", "visible": false},
		{"type": "set_visible", "node": "NPCs/Patron3", "visible": false},
	], func() -> void:
		for npc in room.get_npcs():
			if npc.name.begins_with("Patron") and is_instance_valid(npc):
				npc.queue_free()
		dialog_manager.set_dialog_active(false)
	)
