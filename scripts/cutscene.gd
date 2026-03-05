extends CanvasLayer

signal cutscene_finished

var _slides: Array = []
var _current: int = 0

@onready var bg_rect: ColorRect = $Background
@onready var image_rect: TextureRect = $ImageRect
@onready var text_panel: Panel = $TextPanel
@onready var text_label: Label = $TextPanel/TextLabel
@onready var hint_label: Label = $TextPanel/HintLabel


func play(slides: Array) -> void:
	if slides.is_empty():
		cutscene_finished.emit()
		return
	_slides = slides
	_current = 0
	visible = true
	_show_slide()


func _show_slide() -> void:
	var slide: Dictionary = _slides[_current]
	bg_rect.color = slide.get("background_color", Color.BLACK)
	var img = slide.get("image", null)
	if img != null:
		image_rect.texture = img
		image_rect.visible = true
	else:
		image_rect.visible = false
	text_label.text = slide.get("text", "")


func _process(_delta: float) -> void:
	if not visible:
		return
	var advance := (
		Input.is_action_just_pressed("melee_attack") or
		Input.is_action_just_pressed("ranged_attack") or
		Input.is_action_just_pressed("interact") or
		Input.is_action_just_pressed("move_up") or
		Input.is_action_just_pressed("move_down") or
		Input.is_action_just_pressed("move_left") or
		Input.is_action_just_pressed("move_right")
	)
	if advance:
		_advance()


func _advance() -> void:
	_current += 1
	if _current >= _slides.size():
		visible = false
		cutscene_finished.emit()
	else:
		_show_slide()
