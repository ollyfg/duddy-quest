extends GutTest
## Isolated tests for HUDManager — verifies HP display, key label, rage bar,
## and wand visibility updates.

const HUDManagerScript = preload("res://scripts/hud_manager.gd")


class DummyPlayer:
	extends Node
	const MAX_HP: int = 5
	var hp: int = 5
	var has_wand: bool = false


class DummyMobileControls:
	extends Node
	var _ranged_visible: bool = false
	func set_ranged_visible(v: bool) -> void:
		_ranged_visible = v


func _make_hm() -> Node:
	var hm := HUDManagerScript.new()
	var hp_bar := HBoxContainer.new()
	var key_label := Label.new()
	var rage_bar := ProgressBar.new()
	var mc := DummyMobileControls.new()
	var player := DummyPlayer.new()
	var main := Node.new()
	main.add_child(hp_bar)
	main.add_child(key_label)
	main.add_child(rage_bar)
	main.add_child(mc)
	main.add_child(player)
	main.add_child(hm)
	hm.setup(hp_bar, key_label, rage_bar, mc, player, main)
	add_child_autoqfree(main)
	return hm


# ---------------------------------------------------------------------------
# HP bar
# ---------------------------------------------------------------------------

func test_init_hp_bar_creates_correct_number_of_hearts() -> void:
	var hm := _make_hm()
	hm.init_hp_bar()
	assert_eq(hm._hp_bar.get_child_count(), DummyPlayer.MAX_HP,
		"HP bar should contain MAX_HP heart icons after init")


func test_update_hp_display_full_hp_all_full() -> void:
	var hm := _make_hm()
	hm.init_hp_bar()
	hm.update_hp_display(5)
	for i: int in range(hm._hp_bar.get_child_count()):
		var tr: TextureRect = hm._hp_bar.get_child(i)
		assert_not_null(tr.texture, "All hearts should have a texture at full HP")


func test_update_hp_display_zero_hp_uses_empty_textures() -> void:
	var hm := _make_hm()
	hm.init_hp_bar()
	hm.update_hp_display(0)
	var first_tr: TextureRect = hm._hp_bar.get_child(0)
	assert_eq(first_tr.texture, HUDManagerScript._HEART_EMPTY,
		"At 0 HP the first heart should use the empty texture")


# ---------------------------------------------------------------------------
# Key label
# ---------------------------------------------------------------------------

func test_update_key_display_shows_label_when_keys_present() -> void:
	var hm := _make_hm()
	hm.update_key_display(2)
	assert_true(hm._key_label.visible, "Key label should be visible when player has keys")
	assert_eq(hm._key_label.text, "Key: 2", "Key label text should reflect key count")


func test_update_key_display_hides_label_when_no_keys() -> void:
	var hm := _make_hm()
	hm.update_key_display(0)
	assert_false(hm._key_label.visible, "Key label should be hidden when player has no keys")


# ---------------------------------------------------------------------------
# Rage bar
# ---------------------------------------------------------------------------

func test_update_rage_bar_sets_value_as_percentage() -> void:
	var hm := _make_hm()
	hm.update_rage_bar(0.5)
	assert_almost_eq(hm._rage_bar.value, 50.0, 0.001, "Rage bar value should be 50 for a 0.5 rage fraction")


# ---------------------------------------------------------------------------
# Wand display
# ---------------------------------------------------------------------------

func test_update_wand_display_hides_when_no_wand() -> void:
	var hm := _make_hm()
	(hm._player as DummyPlayer).has_wand = false
	hm.update_wand_display()
	assert_false((hm._mobile_controls as DummyMobileControls)._ranged_visible,
		"Ranged button should be hidden when player has no wand")


func test_update_wand_display_shows_when_wand_present() -> void:
	var hm := _make_hm()
	(hm._player as DummyPlayer).has_wand = true
	hm.update_wand_display()
	assert_true((hm._mobile_controls as DummyMobileControls)._ranged_visible,
		"Ranged button should be visible when player has a wand")
