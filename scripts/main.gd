extends Node2D
## Thin coordinator: connects HUDManager, RoomManager, DialogManager, and
## LevelManager together, wiring up signals and delegating all domain logic.

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

# ---- Manager child nodes ----
var hud_manager: Node = null
var dialog_manager: Node = null
var room_manager: Node = null
var level_manager: Node = null

const _HUD_MANAGER_SCRIPT: Script = preload("res://scripts/hud_manager.gd")
const _DIALOG_MANAGER_SCRIPT: Script = preload("res://scripts/dialog_manager.gd")
const _ROOM_MANAGER_SCRIPT: Script = preload("res://scripts/room_manager.gd")
const _LEVEL_MANAGER_SCRIPT: Script = preload("res://scripts/level_manager.gd")


func _ready() -> void:
	# Instantiate managers.
	hud_manager = Node.new()
	hud_manager.set_script(_HUD_MANAGER_SCRIPT)
	add_child(hud_manager)

	dialog_manager = Node.new()
	dialog_manager.set_script(_DIALOG_MANAGER_SCRIPT)
	add_child(dialog_manager)

	room_manager = Node.new()
	room_manager.set_script(_ROOM_MANAGER_SCRIPT)
	add_child(room_manager)

	level_manager = Node.new()
	level_manager.set_script(_LEVEL_MANAGER_SCRIPT)
	add_child(level_manager)

	# Set up each manager with the references it needs.
	hud_manager.setup(hp_bar, key_label, rage_bar, mobile_controls, player, self)

	dialog_manager.setup(
		dialog_box,
		player,
		func() -> Node: return room_manager.current_room,
		func(seq: Array, cb: Callable) -> void: level_manager.play_cinematic(seq, cb),
		func(dir: String) -> void: room_manager.trigger_exit(dir)
	)

	room_manager.setup(
		room_holder,
		player,
		LEVELS,
		func() -> String: return current_level_name,
		_setup_npc,
		_on_room_post_load,
		_on_locked_exit_attempted
	)
	room_manager._on_level_end_reached_cb = func(t: Node) -> void: level_manager.on_level_end_reached(t)
	room_manager._on_bedroom_door_approached_cb = func() -> void: dialog_manager.on_bedroom_door_approached()

	level_manager.setup(
		LEVELS,
		player,
		dialog_box,
		func(rn: String, pp: Vector2) -> void: room_manager.load_room(rn, pp),
		func(a: bool) -> void: dialog_manager.set_dialog_active(a),
		func() -> Node: return room_manager.current_room,
		func(): return room_manager.get_pathfinder(),
		self
	)

	# Wire player signals to managers.
	player.add_to_group("player")
	player.hp_changed.connect(hud_manager.update_hp_display)
	player.wand_acquired.connect(hud_manager.update_wand_display)
	player.died.connect(hud_manager.on_player_died)
	player.keys_changed.connect(hud_manager.update_key_display)
	player.rage_changed.connect(hud_manager.update_rage_bar)
	player.rage_attack.connect(hud_manager.on_rage_attack)
	dialog_box.dialog_ended.connect(dialog_manager.on_dialog_ended)

	hud_manager.init_hp_bar()

	# Allow launching into a specific level via --level <name> CLI argument.
	var args := OS.get_cmdline_user_args()
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

	_load_level(level_name)


# ---------------------------------------------------------------------------
# Public delegation helpers (keeps the same external API for backward compat)
# ---------------------------------------------------------------------------

func _load_level(level_name: String) -> void:
	current_level_name = level_name
	room_manager._room_states.clear()
	level_manager.current_level_name = level_name
	level_manager.load_level(level_name)


func play_cinematic(sequence: Array, on_finish: Callable) -> void:
	level_manager.play_cinematic(sequence, on_finish)


func play_cutscene(slides: Array, on_finish: Callable) -> void:
	level_manager.play_cutscene(slides, on_finish)


# ---------------------------------------------------------------------------
# NPC wiring — called by room_manager for each NPC after a room loads
# ---------------------------------------------------------------------------

func _setup_npc(npc: Node) -> void:
	if npc.is_in_group("boss") and npc.has_signal("boss_defeated"):
		npc.boss_defeated.connect(level_manager.on_boss_defeated)
		npc.interaction_requested.connect(dialog_manager.on_npc_interaction_requested.bind(npc))
	elif not npc.is_hostile:
		npc.interaction_requested.connect(dialog_manager.on_npc_interaction_requested.bind(npc))
	if npc.detection_dialog != "":
		npc.player_detected.connect(dialog_manager.on_npc_player_detected)
	if npc.cinematic_kick_back:
		npc.add_collision_exception_with(player)
		player.add_collision_exception_with(npc)
		npc.player_hit.connect(dialog_manager.on_petunia_hit_player)


# ---------------------------------------------------------------------------
# Post-load hook — called by room_manager after a room finishes loading
# ---------------------------------------------------------------------------

func _on_room_post_load(room_name: String) -> void:
	hud_manager.update_hp_display(player.hp)
	hud_manager.update_wand_display()
	# Trigger first-visit intro cinematics.
	if room_name == "l1_hallway" and not GameState.l1_hallway_intro_shown:
		level_manager.play_hallway_intro()
	elif room_name == "l1_street" and not GameState.l1_street_intro_shown:
		level_manager.play_street_intro()


# ---------------------------------------------------------------------------
# Locked exit — forwarded from room_manager
# ---------------------------------------------------------------------------

func _on_locked_exit_attempted(_direction: String, _key_id: String) -> void:
	if not dialog_box.is_active():
		dialog_manager.set_dialog_active(true)
		dialog_box.set_speaker("")
		dialog_box.start_dialog(["It's locked."])
