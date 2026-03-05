extends Node2D

## Maps level IDs (matching LEVELS keys in main.gd) to display names.
const LEVEL_LIST: Array[Dictionary] = [
	{"id": "training", "name": "Training"},
]

var _selected: int = 0
var _list_label: Label


func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 0
	add_child(canvas)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.15)
	bg.position = Vector2.ZERO
	bg.size = Vector2(640, 480)
	canvas.add_child(bg)

	var title := Label.new()
	title.text = "SELECT LEVEL"
	title.position = Vector2(0, 60)
	title.size = Vector2(640, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set(&"theme_override_font_sizes/font_size", 36)
	canvas.add_child(title)

	_list_label = Label.new()
	_list_label.position = Vector2(200, 170)
	_list_label.size = Vector2(240, 200)
	_list_label.set(&"theme_override_font_sizes/font_size", 24)
	canvas.add_child(_list_label)
	_update_list()

	var hint := Label.new()
	hint.text = "W / S to navigate     C to select"
	hint.position = Vector2(0, 430)
	hint.size = Vector2(640, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set(&"theme_override_font_sizes/font_size", 16)
	canvas.add_child(hint)


func _update_list() -> void:
	var text := ""
	for i: int in range(LEVEL_LIST.size()):
		var prefix := "> " if i == _selected else "  "
		text += prefix + LEVEL_LIST[i]["name"] + "\n"
	_list_label.text = text


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("move_up"):
		_selected = (_selected - 1 + LEVEL_LIST.size()) % LEVEL_LIST.size()
		_update_list()
	elif Input.is_action_just_pressed("move_down"):
		_selected = (_selected + 1) % LEVEL_LIST.size()
		_update_list()
	elif Input.is_action_just_pressed("melee_attack"):
		GameState.selected_level = LEVEL_LIST[_selected]["id"]
		get_tree().change_scene_to_file("res://scenes/main.tscn")
