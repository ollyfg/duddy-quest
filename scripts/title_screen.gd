extends Node2D

const MobileControls = preload("res://scenes/mobile_controls.tscn")

func _ready() -> void:
	add_child(MobileControls.instantiate())

	var canvas := CanvasLayer.new()
	canvas.layer = 0
	add_child(canvas)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.15)
	bg.position = Vector2.ZERO
	var vp_size: Vector2 = get_viewport_rect().size
	bg.size = vp_size
	canvas.add_child(bg)

	var title := Label.new()
	title.text = "DUDDY QUEST"
	title.position = Vector2(0, 110)
	title.size = Vector2(vp_size.x, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set(&"theme_override_font_sizes/font_size", 48)
	canvas.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Dudley's journey to Hogwarts"
	subtitle.position = Vector2(0, 210)
	subtitle.size = Vector2(vp_size.x, 40)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set(&"theme_override_font_sizes/font_size", 20)
	canvas.add_child(subtitle)

	var prompt_container := HBoxContainer.new()
	# Centre the prompt container (240 px wide) in the viewport.
	prompt_container.position = Vector2((vp_size.x - 240.0) / 2.0, 340)
	prompt_container.size = Vector2(240.0, 40)
	prompt_container.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_container.set(&"theme_override_constants/separation", 8)
	canvas.add_child(prompt_container)

	var key_icon := TextureRect.new()
	key_icon.texture = preload("res://assets/icons/press_key.svg")
	key_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key_icon.custom_minimum_size = Vector2(32, 32)
	prompt_container.add_child(key_icon)

	var prompt := Label.new()
	prompt.text = "Press C to Start"
	prompt.set(&"theme_override_font_sizes/font_size", 24)
	prompt_container.add_child(prompt)

	var version_label := Label.new()
	version_label.text = "v" + GameState.VERSION
	version_label.position = Vector2(0, vp_size.y - 22)
	version_label.size = Vector2(vp_size.x - 10, 20)
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.set(&"theme_override_font_sizes/font_size", 14)
	canvas.add_child(version_label)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("melee_attack"):
		get_tree().change_scene_to_file("res://scenes/level_select.tscn")
