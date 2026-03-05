extends CanvasLayer

signal dialog_ended
signal choice_made(outcome: String)
signal choice_correct

const MAX_DIALOG_OPTIONS: int = 4

var _lines: Array = []
var _current_line: int = 0
var _active: bool = false
var _showing_options: bool = false
var _selected_option: int = 0

@onready var panel: Panel = $Panel
@onready var dialog_label: Label = $Panel/VBox/DialogLabel
@onready var next_button: Button = $Panel/VBox/NextButton
@onready var options_container: VBoxContainer = $Panel/VBox/OptionsContainer


func _ready() -> void:
	panel.visible = false
	next_button.pressed.connect(_on_next_pressed)


## Begin displaying a sequence of dialog lines.
func start_dialog(lines: Array) -> void:
	if lines.is_empty():
		return
	_start_sequence(lines)


## Returns true while a conversation is displayed.
func is_active() -> bool:
	return _active


func _start_sequence(lines: Array) -> void:
	_lines = lines
	_current_line = 0
	_active = true
	panel.visible = true
	_show_current_line()


func _show_current_line() -> void:
	var item = _lines[_current_line]
	if item is String:
		_showing_options = false
		dialog_label.text = item
		next_button.text = "Close" if _current_line >= _lines.size() - 1 else "Next"
		next_button.visible = true
		_clear_options()
		options_container.visible = false
	elif item is Dictionary:
		_showing_options = true
		dialog_label.text = item.get("text", "")
		next_button.visible = false
		_build_option_buttons(item.get("options", []))


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
	_showing_options = false
	_clear_options()
	options_container.visible = false
	var next_seq: Array = chosen.get("next", [])
	if next_seq.is_empty():
		_active = false
		panel.visible = false
		_lines = []
		_current_line = 0
		dialog_ended.emit()
	else:
		_start_sequence(next_seq)


func _process(_delta: float) -> void:
	if not _active:
		return
	if _showing_options:
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
			_on_next_pressed()


func _on_next_pressed() -> void:
	_current_line += 1
	if _current_line >= _lines.size():
		_active = false
		panel.visible = false
		_lines = []
		_current_line = 0
		dialog_ended.emit()
	else:
		_show_current_line()

