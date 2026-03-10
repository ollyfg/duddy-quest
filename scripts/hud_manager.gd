extends Node
## Manages all HUD elements: HP hearts, key counter, rage bar, wand display,
## rage-attack flash overlay, and the game-over screen.

const _HEART_FULL: Texture2D = preload("res://assets/icons/heart_full.svg")
const _HEART_EMPTY: Texture2D = preload("res://assets/icons/heart_empty.svg")

## Untyped to allow accessing player.gd custom signals and properties.
var _player
var _hp_bar: HBoxContainer
var _key_label: Label
var _rage_bar: ProgressBar
## Untyped to allow calling mobile_controls.gd custom methods.
var _mobile_controls


func setup(player, hp_bar: HBoxContainer, key_label: Label, rage_bar: ProgressBar, mobile_controls) -> void:
	_player = player
	_hp_bar = hp_bar
	_key_label = key_label
	_rage_bar = rage_bar
	_mobile_controls = mobile_controls
	player.hp_changed.connect(update_hp_display)
	player.wand_acquired.connect(_on_wand_acquired)
	player.died.connect(_on_player_died)
	player.keys_changed.connect(update_key_display)
	player.rage_changed.connect(update_rage_bar)
	player.rage_attack.connect(_on_rage_attack)
	_init_hp_bar()


func _init_hp_bar() -> void:
	for i: int in range(_player.MAX_HP):
		var tr := TextureRect.new()
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(28, 28)
		_hp_bar.add_child(tr)
	update_hp_display(_player.hp)


func update_hp_display(new_hp: int) -> void:
	for i: int in range(_hp_bar.get_child_count()):
		var tr: TextureRect = _hp_bar.get_child(i)
		tr.texture = _HEART_FULL if i < new_hp else _HEART_EMPTY


func update_key_display(count: int) -> void:
	if count > 0:
		_key_label.text = "Key: %d" % count
		_key_label.visible = true
	else:
		_key_label.visible = false


func update_rage_bar(value: float) -> void:
	_rage_bar.value = value * 100.0


func update_wand_display() -> void:
	_mobile_controls.set_ranged_visible(_player.has_wand)


func _on_wand_acquired() -> void:
	update_wand_display()


func _on_rage_attack() -> void:
	play_flash(Color(1.0, 0.4, 0.0, 0.7), 0.3)


## Play a coloured screen-flash overlay.  Used by rage attack and the wand
## acquisition golden flash.
func play_flash(flash_color: Color, duration: float) -> void:
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 15
	get_parent().add_child(flash_layer)
	var flash_rect := ColorRect.new()
	flash_rect.color = flash_color
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_layer.add_child(flash_rect)
	var tween := get_parent().create_tween()
	tween.tween_interval(0.1)
	tween.tween_property(flash_rect, "color:a", 0.0, duration)
	tween.tween_callback(flash_layer.queue_free)


func _on_player_died() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	get_parent().add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var label := Label.new()
	label.text = "GAME OVER"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font_size_prop := &"theme_override_font_sizes/font_size"
	label.set(font_size_prop, 32)
	overlay.add_child(label)

	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
