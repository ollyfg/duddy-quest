## DevTools: file-based IPC server for automated playtesting.
##
## Activated by passing -- --dev-tools on the Godot command line.
## When active this node polls a command file every POLL_INTERVAL seconds,
## executes the requested command, and writes the result back.
##
## Command file : /tmp/duddy_quest_cmd.json
## Result file  : /tmp/duddy_quest_result.json
##
## Supported command types
## -----------------------
##   screenshot  {"type":"screenshot","path":"/tmp/shot.png"}
##   input       {"type":"input","action":"move_right","pressed":true,"duration":1.0}
##   state       {"type":"state"}
##
## See tools/playtest.py for the matching Python client.
extends Node

const CMD_FILE := "/tmp/duddy_quest_cmd.json"
const RESULT_FILE := "/tmp/duddy_quest_result.json"
## How often (seconds) to check for a new command file.
const POLL_INTERVAL := 0.05

var _poll_timer: float = 0.0


func _ready() -> void:
	if "--dev-tools" not in OS.get_cmdline_user_args():
		set_process(false)
		return
	# Remove stale files left from a previous session.
	if FileAccess.file_exists(CMD_FILE):
		DirAccess.remove_absolute(CMD_FILE)
	if FileAccess.file_exists(RESULT_FILE):
		DirAccess.remove_absolute(RESULT_FILE)
	print("DevTools: ready. Command file: %s" % CMD_FILE)


func _process(delta: float) -> void:
	_poll_timer -= delta
	if _poll_timer > 0.0:
		return
	_poll_timer = POLL_INTERVAL

	if not FileAccess.file_exists(CMD_FILE):
		return

	var file := FileAccess.open(CMD_FILE, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	# Consume the command file immediately so a new command can be queued.
	DirAccess.remove_absolute(CMD_FILE)

	var json := JSON.new()
	if json.parse(content) != OK:
		_write_result({"error": "Invalid JSON in command file"})
		return

	_dispatch(json.get_data())


func _dispatch(cmd: Dictionary) -> void:
	match cmd.get("type", ""):
		"screenshot":
			_cmd_screenshot(cmd)
		"input":
			_cmd_input(cmd)
		"state":
			_write_result(_build_state())
		var unknown:
			_write_result({"error": "Unknown command type: %s" % unknown})


func _cmd_screenshot(cmd: Dictionary) -> void:
	var path: String = cmd.get("path", "/tmp/duddy_screenshot.png")
	var image := get_viewport().get_texture().get_image()
	if image == null:
		_write_result({"error": "Could not capture viewport image"})
		return
	var err := image.save_png(path)
	if err == OK:
		_write_result({"ok": true, "path": path})
	else:
		_write_result({"error": "Failed to save PNG (err %d)" % err})


func _cmd_input(cmd: Dictionary) -> void:
	var action: String = cmd.get("action", "")
	var pressed: bool = cmd.get("pressed", true)
	var duration: float = cmd.get("duration", 0.0)

	if not InputMap.has_action(action):
		_write_result({"error": "Unknown action: %s" % action})
		return

	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)

	# Auto-release after the requested duration.
	if pressed and duration > 0.0:
		get_tree().create_timer(duration).timeout.connect(func() -> void:
			var release := InputEventAction.new()
			release.action = action
			release.pressed = false
			Input.parse_input_event(release)
		)

	_write_result({"ok": true, "action": action, "pressed": pressed})


func _build_state() -> Dictionary:
	var state: Dictionary = {}

	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p := players[0]
		state["player"] = {
			"x": snappedf(p.global_position.x, 0.01),
			"y": snappedf(p.global_position.y, 0.01),
			"hp": p.hp if "hp" in p else -1,
		}
	else:
		state["player"] = null

	var main := get_tree().get_root().get_node_or_null("Main")
	if main != null and "current_room_name" in main:
		state["room"] = main.current_room_name
		var db = main.get_node_or_null("HUD/DialogBox")
		state["dialog_active"] = db != null and db.is_active()
		if main.current_room != null:
			var npcs_node = main.current_room.get_node_or_null("NPCs")
			if npcs_node:
				var npc_positions = []
				for npc in npcs_node.get_children():
					npc_positions.append({"x": snappedf(npc.global_position.x, 0.01), "y": snappedf(npc.global_position.y, 0.01), "hostile": npc.is_hostile})
				state["npcs"] = npc_positions
	else:
		state["room"] = null

	return state


func _write_result(data: Dictionary) -> void:
	var file := FileAccess.open(RESULT_FILE, FileAccess.WRITE)
	if file == null:
		push_error("DevTools: could not write result to %s" % RESULT_FILE)
		return
	file.store_string(JSON.stringify(data))
	file.close()
