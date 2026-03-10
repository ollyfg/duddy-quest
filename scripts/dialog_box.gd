extends CanvasLayer

signal dialog_ended
signal choice_made(outcome: String)
signal choice_correct
## Emitted when a dialog option requests setting a GameState flag.
signal set_flag_requested(flag_name: String)
## Emitted when a dialog option requests removing a key from player inventory.
signal remove_key_requested(key_id: String)

const MAX_DIALOG_OPTIONS: int = 4

## Speed of the typewriter effect in characters per second.
const TYPEWRITER_CPS: float = 30.0

var _lines: Array = []
var _current_line: int = 0
var _active: bool = false
var _showing_options: bool = false
var _selected_option: int = 0

## Typewriter state
var _typewriter_total: int = 0
var _typewriter_shown: float = 0.0
var _typewriter_done: bool = true

@onready var panel: Panel = $Panel
@onready var speaker_label: Label = $Panel/VBox/SpeakerLabel
@onready var dialog_label: Label = $Panel/VBox/DialogLabel
@onready var options_container: VBoxContainer = $Panel/VBox/OptionsContainer


func _ready() -> void:
	panel.visible = false


## Begin displaying a sequence of dialog lines.
func start_dialog(lines: Array) -> void:
	if lines.is_empty():
		return
	_start_sequence(lines)


## Set the NPC speaker name shown above the dialog text.
## Pass an empty string to hide the speaker label (for system messages).
func set_speaker(name: String) -> void:
	if name.is_empty():
		speaker_label.visible = false
		speaker_label.text = ""
	else:
		speaker_label.text = name
		speaker_label.visible = true


## Returns true while a conversation is displayed.
func is_active() -> bool:
	return _active


func _start_sequence(lines: Array) -> void:
	if OS.is_debug_build():
		for item in lines:
			_validate_dialog_item(item)
	_lines = lines
	_current_line = 0
	_active = true
	panel.visible = true
	_show_current_line()


## Validate a single dialog item in debug builds.
## Returns true if the item is well-formed, false and emits push_error otherwise.
static func _validate_dialog_item(item: Variant) -> bool:
	if item is Dictionary and not item.has("text"):
		push_error("Dialog item is a Dictionary but is missing the required 'text' key: %s" % str(item))
		return false
	return true


func _show_current_line() -> void:
	var item = _lines[_current_line]
	if item is String:
		_showing_options = false
		dialog_label.text = item
		_start_typewriter(item)
		_clear_options()
		options_container.visible = false
	elif item is Dictionary:
		_showing_options = true
		var text: String = item.get("text", "")
		dialog_label.text = text
		_start_typewriter(text)
		_build_option_buttons(item.get("options", []))


## Begin typewriter animation for the given text.
func _start_typewriter(text: String) -> void:
	_typewriter_total = text.length()
	_typewriter_shown = 0.0
	_typewriter_done = _typewriter_total == 0
	dialog_label.visible_characters = 0 if not _typewriter_done else -1


## Instantly reveal remaining typewriter characters.
func _finish_typewriter() -> void:
	_typewriter_done = true
	dialog_label.visible_characters = -1


func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()


func _build_option_buttons(options: Array) -> void:
	_clear_options()
	_selected_option = 0
	var count: int = mini(options.size(), MAX_DIALOG_OPTIONS)
	for i in range(count):
		var opt: Dictionary = options[i]
		var btn: Button = Button.new()
		btn.text = opt.get("label", "")
		btn.custom_minimum_size = Vector2(0, 44)
		btn.layout_mode = 2
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_option_selected(idx))
		options_container.add_child(btn)
	options_container.visible = true
	if options_container.get_child_count() > 0:
		options_container.get_child(0).grab_focus()


func _on_option_selected(index: int) -> void:
	var item = _lines[_current_line]
	if not (item is Dictionary):
		return
	var options: Array = item.get("options", [])
	if index >= options.size():
		return
	var chosen: Dictionary = options[index]
	var outcome: String = chosen.get("outcome", "")
	choice_made.emit(outcome)
	if chosen.get("correct", false):
		choice_correct.emit()
	# Emit flag-setting requests embedded in the option dict.
	var single_flag: String = chosen.get("flag", "")
	if single_flag != "":
		set_flag_requested.emit(single_flag)
	for f in chosen.get("flags", []):
		var flag_str: String = str(f)
		if not flag_str.is_empty():
			set_flag_requested.emit(flag_str)
	# Emit a key-removal request if the option carries a "remove_key" field.
	var rk: String = chosen.get("remove_key", "")
	if rk != "":
		remove_key_requested.emit(rk)
	_showing_options = false
	_clear_options()
	options_container.visible = false
	var next_seq: Array = chosen.get("next", [])
	if next_seq.is_empty():
		_active = false
		panel.visible = false
		_lines = []
		_current_line = 0
		set_speaker("")
		dialog_ended.emit()
	else:
		_start_sequence(next_seq)


func _process(delta: float) -> void:
	if not _active:
		return

	# Advance typewriter animation
	if not _typewriter_done:
		_typewriter_shown += delta * TYPEWRITER_CPS
		var chars: int = int(_typewriter_shown)
		if chars >= _typewriter_total:
			_finish_typewriter()
		else:
			dialog_label.visible_characters = chars

	if _showing_options:
		# Wait for typewriter to finish before allowing option navigation
		if not _typewriter_done:
			if Input.is_action_just_pressed("melee_attack") or Input.is_action_just_pressed("ranged_attack"):
				_finish_typewriter()
			return
		var btn_count: int = options_container.get_child_count()
		if btn_count == 0:
			return
		if Input.is_action_just_pressed("move_up"):
			_selected_option = (_selected_option - 1 + btn_count) % btn_count
			options_container.get_child(_selected_option).grab_focus()
		elif Input.is_action_just_pressed("move_down"):
			_selected_option = (_selected_option + 1) % btn_count
			options_container.get_child(_selected_option).grab_focus()
		elif Input.is_action_just_pressed("melee_attack") or Input.is_action_just_pressed("ranged_attack"):
			_on_option_selected(_selected_option)
	else:
		if Input.is_action_just_pressed("melee_attack") or Input.is_action_just_pressed("ranged_attack"):
			if not _typewriter_done:
				_finish_typewriter()
			else:
				_advance_line()


func _advance_line() -> void:
	_current_line += 1
	if _current_line >= _lines.size():
		_active = false
		panel.visible = false
		_lines = []
		_current_line = 0
		set_speaker("")
		dialog_ended.emit()
	else:
		_show_current_line()

