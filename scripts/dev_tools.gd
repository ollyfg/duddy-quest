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
##   screenshot          {"type":"screenshot","path":"/tmp/shot.png"}
##   input               {"type":"input","action":"move_right","pressed":true,"duration":1.0}
##   state               {"type":"state"}
##   spawn               {"type":"spawn","room":"l1_hallway","x":200.0,"y":240.0}
##                       room, x, and y are all optional; omit room to stay in the
##                       current room, omit x/y to use the centre of the viewport.
##   set_mobile_viewport {"type":"set_mobile_viewport","enabled":true}
##                       Enable or disable mobile viewport simulation.  Toggles
##                       the on-screen controls, resizes the window, and adjusts
##                       the camera to match the mobile layout.
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
		"spawn":
			_cmd_spawn(cmd)
		"set_mobile_viewport":
			_cmd_set_mobile_viewport(cmd)
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
			"has_wand": p.has_wand if "has_wand" in p else false,
		}
	else:
		state["player"] = null

	var main := get_tree().get_root().get_node_or_null("Main")
	var room_manager = main.room_manager if main != null and "room_manager" in main else null
	if room_manager != null:
		state["room"] = room_manager.current_room_name
		state["level"] = main.current_level_name if "current_level_name" in main else null
		var db = main.get_node_or_null("HUD/DialogBox")
		state["dialog_active"] = db != null and db.is_active()
		if room_manager.current_room != null:
			var npcs_node = room_manager.current_room.get_node_or_null("NPCs")
			if npcs_node:
				var npc_positions = []
				for npc in npcs_node.get_children():
					npc_positions.append({"x": snappedf(npc.global_position.x, 0.01), "y": snappedf(npc.global_position.y, 0.01), "hostile": npc.is_hostile})
				state["npcs"] = npc_positions
	else:
		state["room"] = null
		state["level"] = null

	return state


func _cmd_spawn(cmd: Dictionary) -> void:
	var main := get_tree().get_root().get_node_or_null("Main")
	if main == null:
		_write_result({"error": "Main node not found"})
		return
	var room_manager = main.room_manager if "room_manager" in main else null
	if room_manager == null:
		_write_result({"error": "room_manager not found"})
		return

	var room_name: String = cmd.get("room", "")
	var has_x: bool = "x" in cmd
	var has_y: bool = "y" in cmd
	var x: float = float(cmd.get("x", 320.0))
	var y: float = float(cmd.get("y", 240.0))

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_write_result({"error": "No player found"})
		return
	var p := players[0]

	if room_name != "":
		if room_manager.is_loading():
			_write_result({"error": "Room transition already in progress"})
			return
		var level_rooms: Dictionary = main.LEVELS[main.current_level_name]["rooms"]
		if room_name not in level_rooms:
			_write_result({"error": "Room '%s' not found in level '%s'" % [room_name, main.current_level_name]})
			return
		var pos := Vector2(x, y) if (has_x and has_y) else Vector2(320.0, 240.0)
		await room_manager.load_room(room_name, pos)
	elif has_x and has_y:
		p.global_position = Vector2(x, y)
		p.cancel_movement()
	else:
		_write_result({"error": "spawn requires at least 'room' or both 'x' and 'y'"})
		return

	var result: Dictionary = {"ok": true}
	result["room"] = room_manager.current_room_name
	result["x"] = snappedf(p.global_position.x, 0.01)
	result["y"] = snappedf(p.global_position.y, 0.01)
	_write_result(result)


func _cmd_set_mobile_viewport(cmd: Dictionary) -> void:
	var enabled: bool = cmd.get("enabled", true)

	# Resize window / content-scale to mobile (640×770) or desktop (640×480).
	var target_size := Vector2i(640, 770) if enabled else Vector2i(640, 480)
	get_window().content_scale_size = target_size
	DisplayServer.window_set_size(target_size)

	# Toggle the MobileControls CanvasLayer.
	var main := get_tree().get_root().get_node_or_null("Main")
	var mc = main.get_node_or_null("MobileControls") if main != null else null
	if mc != null:
		mc.visible = enabled

	# Apply or remove the camera offset that shifts the game view above the
	# on-screen controls.
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p = players[0]
		if p.has_method("set_mobile_camera_offset"):
			if enabled:
				var cam: Camera2D = p.get_node_or_null("Camera2D") as Camera2D
				var zoom_y: float = cam.zoom.y if cam != null else 2.0
				# 290 = height of the on-screen controls in viewport-logical px.
				p.set_mobile_camera_offset(290.0 / zoom_y)
			else:
				p.set_mobile_camera_offset(0.0)
		# Re-apply camera limits for the current room so the extended bottom
		# limit is updated.
		var room_manager = main.room_manager if main != null and "room_manager" in main else null
		if room_manager != null and room_manager.current_room != null:
			p.set_camera_limits(room_manager.current_room.get_room_rect())

	_write_result({"ok": true, "enabled": enabled})


func _write_result(data: Dictionary) -> void:
	var file := FileAccess.open(RESULT_FILE, FileAccess.WRITE)
	if file == null:
		push_error("DevTools: could not write result to %s" % RESULT_FILE)
		return
	file.store_string(JSON.stringify(data))
	file.close()
