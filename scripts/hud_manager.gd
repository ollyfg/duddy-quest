extends Node
## Manages all HUD elements: HP bar, key label, rage bar, wand display,
## the game-over overlay, and the rage-attack screen flash.

const _HEART_FULL: Texture2D = preload("res://assets/icons/heart_full.svg")
const _HEART_EMPTY: Texture2D = preload("res://assets/icons/heart_empty.svg")

var _hp_bar: HBoxContainer = null
var _key_label: Label = null
var _rage_bar: ProgressBar = null
var _mobile_controls = null
var _player = null
# Back-reference to main node for tree operations (create_tween, add_child).
var _main: Node = null


func setup(
		p_hp_bar: HBoxContainer,
		p_key_label: Label,
		p_rage_bar: ProgressBar,
		p_mobile_controls: Node,
		p_player: Node,
		p_main: Node) -> void:
	_hp_bar = p_hp_bar
	_key_label = p_key_label
	_rage_bar = p_rage_bar
	_mobile_controls = p_mobile_controls
	_player = p_player
	_main = p_main


func init_hp_bar() -> void:
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


func on_rage_attack() -> void:
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 15
	_main.add_child(flash_layer)
	var flash_rect := ColorRect.new()
	flash_rect.color = Color(1.0, 0.4, 0.0, 0.7)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_layer.add_child(flash_rect)
	var tween := _main.create_tween()
	tween.tween_interval(0.1)
	tween.tween_property(flash_rect, "color:a", 0.0, 0.3)
	tween.tween_callback(flash_layer.queue_free)


func on_player_died() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	_main.add_child(overlay)

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

	await _main.get_tree().create_timer(2.5).timeout
	_main.get_tree().change_scene_to_file("res://scenes/level_select.tscn")
