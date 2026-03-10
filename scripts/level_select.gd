extends Node2D

const MobileControls = preload("res://scenes/mobile_controls.tscn")

## Maps level IDs (matching LEVELS keys in main.gd) to display names.
const LEVEL_LIST: Array[Dictionary] = [
	{"id": "level_1",  "name": "Level 1 - Privet Drive"},
	{"id": "level_2",  "name": "Level 2 - Diagon Alley"},
	{"id": "level_3",  "name": "Level 3 - King's Cross"},
	{"id": "level_4",  "name": "Level 4 - Hogwarts"},
]

var _selected: int = 0
var _list_label: Label


func _ready() -> void:
	add_child(MobileControls.instantiate())

	var canvas := CanvasLayer.new()
	canvas.layer = 0
	add_child(canvas)

	var viewport_size: Vector2 = get_viewport_rect().size

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.15)
	bg.position = Vector2.ZERO
	bg.size = viewport_size
	canvas.add_child(bg)

	var title := Label.new()
	title.text = "SELECT LEVEL"
	title.position = Vector2(0, 60)
	title.size = Vector2(viewport_size.x, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set(&"theme_override_font_sizes/font_size", 36)
	canvas.add_child(title)

	_list_label = Label.new()
	# Centre the list in the viewport (240 px wide, start at (vp_width - 240) / 2).
	_list_label.position = Vector2((viewport_size.x - 240.0) / 2.0, 170)
	_list_label.size = Vector2(240.0, 200)
	_list_label.set(&"theme_override_font_sizes/font_size", 24)
	canvas.add_child(_list_label)
	_update_list()

	var hint := Label.new()
	hint.text = "W / S to navigate     C to select"
	hint.position = Vector2(0, viewport_size.y - 50)
	hint.size = Vector2(viewport_size.x, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set(&"theme_override_font_sizes/font_size", 16)
	canvas.add_child(hint)


func _is_unlocked(_index: int) -> bool:
	# HACK: all levels unlocked during development.
	return true


func _update_list() -> void:
	var text := ""
	for i: int in range(LEVEL_LIST.size()):
		var unlocked := _is_unlocked(i)
		var prefix := ""
		if i == _selected:
			prefix = "> "
		elif not unlocked:
			prefix = "  [X] "
		else:
			prefix = "  "
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
		if not _is_unlocked(_selected):
			return
		GameState.selected_level = LEVEL_LIST[_selected]["id"]
		get_tree().change_scene_to_file("res://scenes/main.tscn")
