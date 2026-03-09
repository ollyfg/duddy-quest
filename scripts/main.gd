extends Node2D

# Each level groups its rooms, connections, starting room and starting position.
const LEVELS: Dictionary = {
	"level_1": {
		"title": "A Perfectly Normal Catastrophe",
		"next_level": "",
		"start_room": "l1_bedroom",
		"start_pos": Vector2(80.0, 240.0),
		"rooms": {
			"l1_bedroom": preload("res://scenes/l1_bedroom.tscn"),
			"l1_dining_room": preload("res://scenes/l1_dining_room.tscn"),
			"l1_upper_hall": preload("res://scenes/l1_upper_hall.tscn"),
			"l1_hallway": preload("res://scenes/l1_hallway.tscn"),
			"l1_front_hall": preload("res://scenes/l1_front_hall.tscn"),
			"l1_garden": preload("res://scenes/l1_garden.tscn"),
			"l1_street": preload("res://scenes/l1_street.tscn"),
			"l1_vernon_room": preload("res://scenes/l1_vernon_room.tscn"),
		},
		"connections": {
			"l1_bedroom": {
				"east": {"room": "l1_upper_hall", "entry": Vector2(64.0, 160.0)},
			},
			"l1_upper_hall": {
				"west": {"room": "l1_bedroom", "entry": Vector2(576.0, 160.0)},
				"east": {"room": "l1_hallway", "entry": Vector2(64.0, 320.0)},
				"north": {"room": "l1_vernon_room", "entry": Vector2(192.0, 416.0)},
			},
			"l1_vernon_room": {
				"south": {"room": "l1_upper_hall", "entry": Vector2(192.0, 64.0)},
			},
			"l1_hallway": {
				"west": {"room": "l1_upper_hall", "entry": Vector2(576.0, 320.0)},
				"east": {"room": "l1_front_hall", "entry": Vector2(64.0, 160.0)},
			},
			"l1_front_hall": {
				"west": {"room": "l1_hallway", "entry": Vector2(576.0, 160.0)},
				"east": {"room": "l1_garden", "entry": Vector2(64.0, 320.0)},
			},
			"l1_garden": {
				"west": {"room": "l1_front_hall", "entry": Vector2(576.0, 320.0)},
				"east": {"room": "l1_street", "entry": Vector2(64.0, 160.0)},
			},
			"l1_street": {
				"west": {"room": "l1_garden", "entry": Vector2(576.0, 160.0)},
			},
		},
	},
}

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
