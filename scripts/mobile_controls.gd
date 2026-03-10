extends CanvasLayer

# Mobile on-screen control panel.
# Simulates keyboard input actions so the rest of the game needs no changes.
# Visibility is driven by touchscreen availability so the overlay is hidden on
# desktop browsers / non-touch devices.
#
# Multi-touch is handled directly via InputEventScreenTouch so that multiple
# buttons (e.g. move + attack) can be held at the same time.  Each finger is
# tracked independently by its index.

# Maps touch finger index -> action name currently held by that finger.
var _touch_actions: Dictionary = {}

# Maps button node names to their corresponding input actions.
const _BTN_ACTIONS: Dictionary = {
	"BtnUp": "move_up",
	"BtnDown": "move_down",
	"BtnLeft": "move_left",
	"BtnRight": "move_right",
	"BtnMelee": "melee_attack",
	"BtnRanged": "ranged_attack",
}

@onready var _overlay: Control = $Overlay

# Cached mapping: action name -> Button node (populated in _ready).
var _action_buttons: Dictionary = {}
# Cached reference to the ranged-attack button for quick visibility toggling.
var _btn_ranged: Button
# Whether the game was launched with --dev-tools (show all buttons for screenshots).
var _is_dev_tools: bool = false


## Maps button node names to their SVG icon textures.
const _BTN_ICONS: Dictionary = {
	"BtnUp":       preload("res://assets/icons/arrow_up.svg"),
	"BtnDown":     preload("res://assets/icons/arrow_down.svg"),
	"BtnLeft":     preload("res://assets/icons/arrow_left.svg"),
	"BtnRight":    preload("res://assets/icons/arrow_right.svg"),
	"BtnMelee":    preload("res://assets/icons/bat.svg"),
	"BtnRanged":   preload("res://assets/icons/lightning.svg"),
}

## Logical viewport dimensions (must match project.godot viewport_width/height).
const VIEWPORT_WIDTH: float = 640.0
const VIEWPORT_HEIGHT: float = 770.0


func _ready() -> void:
	_is_dev_tools = "--dev-tools" in OS.get_cmdline_user_args()
	visible = DisplayServer.is_touchscreen_available() or _is_dev_tools
	# On non-touchscreen devices (desktop), the controls area is invisible so
	# shrink the logical canvas and OS window back to just the game viewport to
	# avoid an empty black strip below the room.
	if not DisplayServer.is_touchscreen_available() and not _is_dev_tools:
		get_window().content_scale_size = Vector2i(640, 480)
		DisplayServer.window_set_size(Vector2i(640, 480))
	# Set SVG icons on each button and clear the placeholder text.
	for btn_name: String in _BTN_ACTIONS:
		var btn: Button = _overlay.get_node(btn_name)
		btn.text = ""
		btn.icon = _BTN_ICONS[btn_name]
		btn.expand_icon = true
		_action_buttons[_BTN_ACTIONS[btn_name]] = btn
		if btn_name == "BtnRanged":
			_btn_ranged = btn
	# The ranged button is hidden until the player acquires the wand.
	# In dev-tools mode show it unconditionally so it can be screenshotted.
	if not _is_dev_tools:
		_btn_ranged.visible = false
	# Shift controls up so they clear the system navigation bar / home
	# indicator on devices where the viewport fills the full screen height.
	_apply_safe_area_margins()
	# Apply mobile camera offset after all nodes are ready so the player
	# Camera2D is already configured.
	if visible:
		call_deferred("_apply_mobile_camera_offset")


## Compensates for the system safe-area bottom inset (navigation bar / home
## indicator) so that mobile controls are not hidden behind system UI.
## Only adjusts when the game's rendered bottom edge actually overlaps the
## unsafe zone; on tall portrait phones with letterbox bars the game bottom
## is already well above the navigation bar so no adjustment is needed.
func _apply_safe_area_margins() -> void:
	var screen_size := DisplayServer.screen_get_size()
	if screen_size.y <= 0:
		return
	var safe_area := DisplayServer.get_display_safe_area()
	var bottom_inset_px := screen_size.y - safe_area.end.y
	if bottom_inset_px <= 0:
		return
	# With stretch/mode=canvas_items and stretch/aspect=keep the viewport is
	# uniformly scaled to fit inside the screen (black bars on whichever axis
	# has extra space).  The scale factor is the smaller of the two per-axis
	# ratios and the game is centred on screen.
	var scale := minf(float(screen_size.x) / VIEWPORT_WIDTH, float(screen_size.y) / VIEWPORT_HEIGHT)
	if scale <= 0.0:
		return
	# Bottom edge of the rendered game in screen pixels (centred).
	var game_bottom_px := (float(screen_size.y) + VIEWPORT_HEIGHT * scale) / 2.0
	var safe_bottom_px := float(screen_size.y) - float(bottom_inset_px)
	var overlap_px := game_bottom_px - safe_bottom_px
	if overlap_px <= 0.0:
		return
	# Convert the overlap to logical viewport pixels and shift every
	# bottom-anchored control node up by that amount.
	var inset_vp := overlap_px / scale
	var background: ColorRect = _overlay.get_node_or_null("ControlsBackground")
	if background:
		background.offset_top -= inset_vp
		background.offset_bottom -= inset_vp
	for btn_name: String in _BTN_ACTIONS:
		var btn: Button = _overlay.get_node_or_null(btn_name)
		if btn:
			btn.offset_top -= inset_vp
			btn.offset_bottom -= inset_vp


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		# InputEventScreenDrag fires only while the finger is moving on screen.
		# Finger lift always produces InputEventScreenTouch(pressed=false), so
		# passing pressed=true here is correct – the drag is an active contact.
		_handle_touch(event.index, event.position, true)


func _handle_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if not pressed:
		if _touch_actions.has(index):
			Input.action_release(_touch_actions[index])
			_touch_actions.erase(index)
		return

	var action := _action_at(pos)

	# If this finger was already holding a different action, release it first.
	if _touch_actions.has(index):
		if _touch_actions[index] == action:
			return  # Same button – nothing to do.
		Input.action_release(_touch_actions[index])
		_touch_actions.erase(index)

	if action != "":
		_touch_actions[index] = action
		Input.action_press(action)


func _action_at(pos: Vector2) -> String:
	for action: String in _action_buttons:
		var btn: Button = _action_buttons[action]
		if btn.get_global_rect().has_point(pos):
			return action
	return ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		for action: String in _touch_actions.values():
			Input.action_release(action)
		_touch_actions.clear()


## Show or hide the ranged-attack button.  Call this when the player acquires
## (or loses) the wand so the button only appears when it is usable.
## In dev-tools mode the button stays visible unconditionally for screenshots.
func set_ranged_visible(show: bool) -> void:
	if not _is_dev_tools:
		_btn_ranged.visible = show


## Height of the on-screen controls area in viewport-logical pixels.
const CONTROLS_HEIGHT: float = 290.0


## Tells the player Camera2D to shift downward so the visible game area
## (above the touch controls) stays centred on the player.
func _apply_mobile_camera_offset() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("set_mobile_camera_offset"):
		return
	var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	var zoom_y: float = cam.zoom.y if cam != null else 2.0
	player.set_mobile_camera_offset(CONTROLS_HEIGHT / zoom_y)
