extends CanvasLayer

signal dialog_ended

var _lines: Array = []
var _current_line: int = 0
var _active: bool = false

@onready var panel: Panel = $Panel
@onready var dialog_label: Label = $Panel/VBox/DialogLabel
@onready var next_button: Button = $Panel/VBox/NextButton


func _ready() -> void:
panel.visible = false
next_button.pressed.connect(_on_next_pressed)


## Begin displaying a sequence of dialog lines.
func start_dialog(lines: Array) -> void:
if lines.is_empty():
return
_lines = lines
_current_line = 0
_active = true
panel.visible = true
_show_current_line()


## Returns true while a conversation is displayed.
func is_active() -> bool:
return _active


func _show_current_line() -> void:
dialog_label.text = _lines[_current_line]
next_button.text = "Close" if _current_line >= _lines.size() - 1 else "Next"


func _process(_delta: float) -> void:
if not _active:
return
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
