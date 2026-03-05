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


func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available()
	for btn_name: String in _BTN_ACTIONS:
		_action_buttons[_BTN_ACTIONS[btn_name]] = _overlay.get_node(btn_name)
	_btn_ranged = _overlay.get_node("BtnRanged")
	# The ranged button is hidden until the player acquires the wand.
	_btn_ranged.visible = false


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
func set_ranged_visible(show: bool) -> void:
	_btn_ranged.visible = show
