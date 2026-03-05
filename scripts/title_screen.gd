extends Node2D

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
	title.text = "DUDDY QUEST"
	title.position = Vector2(0, 110)
	title.size = Vector2(640, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set(&"theme_override_font_sizes/font_size", 48)
	canvas.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Dudley's journey to Hogwarts"
	subtitle.position = Vector2(0, 210)
	subtitle.size = Vector2(640, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set(&"theme_override_font_sizes/font_size", 20)
	canvas.add_child(subtitle)

	var prompt := Label.new()
	prompt.text = "Press C to Start"
	prompt.position = Vector2(0, 340)
	prompt.size = Vector2(640, 40)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set(&"theme_override_font_sizes/font_size", 24)
	canvas.add_child(prompt)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("melee_attack"):
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")
