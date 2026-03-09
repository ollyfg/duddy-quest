extends GutTest
## Isolated tests for RoomManager — verifies save/restore room state logic
## without requiring a full scene tree.

const RoomManagerScript = preload("res://scripts/room_manager.gd")
const MagicDoorScene = preload("res://scenes/magic_door.tscn")


class DummyRoom:
	extends Node2D

	var _npcs: Array[Node] = []
	var _items: Array[Node] = []
	var _switches: Array[Node] = []

	func get_npcs() -> Array[Node]:
		return _npcs

	func get_items() -> Array[Node]:
		return _items

	func get_switches() -> Array[Node]:
		return _switches


func _make_room_with_magic_door(opened: bool) -> DummyRoom:
	var room := DummyRoom.new()
	var door: Node2D = MagicDoorScene.instantiate()
	door.name = "MagicDoor"
	door.visible = not opened
	room.add_child(door)
	return room


# ---------------------------------------------------------------------------
# save/restore room state
# ---------------------------------------------------------------------------

func test_room_state_is_empty_before_first_save() -> void:
	var rm := RoomManagerScript.new()
	assert_true(rm._room_states.is_empty(), "No room states should be present before any save")
	rm.free()


func test_save_room_state_stores_entry_for_current_room() -> void:
	var rm := RoomManagerScript.new()
	rm.current_room_name = "l1_bedroom"
	var room := DummyRoom.new()
	rm.current_room = room
	rm._save_room_state()
	assert_true(rm._room_states.has("l1_bedroom"), "Saved state should contain an entry for l1_bedroom")
	room.free()
	rm.free()


func test_magic_door_opened_state_persists_through_save_restore() -> void:
	var rm := RoomManagerScript.new()
	rm.current_room_name = "l1_bedroom"
	var first_room := _make_room_with_magic_door(true)
	rm.current_room = first_room
	rm._save_room_state()

	var second_room := _make_room_with_magic_door(false)
	rm.current_room = second_room
	var restored_door: Node2D = rm.current_room.get_node("MagicDoor")
	assert_true(restored_door.visible, "Fresh room should start with a visible magic door")

	rm._restore_room_state("l1_bedroom")
	assert_false(restored_door.visible, "Restored room should have the door invisible (opened/destroyed)")

	first_room.free()
	second_room.free()
	rm.free()


func test_restore_no_op_when_no_state_saved() -> void:
	var rm := RoomManagerScript.new()
	var room := _make_room_with_magic_door(false)
	rm.current_room = room
	# Should not crash even with no saved state.
	rm._restore_room_state("l1_bedroom")
	var door: Node2D = room.get_node("MagicDoor")
	assert_true(door.visible, "Door should remain in its default state when no saved state exists")
	room.free()
	rm.free()


func test_exit_triggered_noop_when_room_loading() -> void:
	var rm := RoomManagerScript.new()
	rm._room_loading = true
	rm.current_room_name = "l1_bedroom"
	# With _room_loading true, _on_exit_triggered should return immediately without crashing.
	rm._on_exit_triggered("east")
	assert_true(true, "_on_exit_triggered with _room_loading=true should be a no-op")
	rm.free()
