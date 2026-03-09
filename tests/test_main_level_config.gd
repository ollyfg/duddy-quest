extends GutTest

const MainScript = preload("res://scripts/main.gd")
const RoomManagerScript = preload("res://scripts/room_manager.gd")
const LevelEndTriggerScene = preload("res://scenes/level_end_trigger.tscn")
const MagicDoorScene = preload("res://scenes/magic_door.tscn")


class DummyRoom:
	extends Node2D

	func get_npcs() -> Array[Node]:
		return []

	func get_items() -> Array[Node]:
		return []

	func get_switches() -> Array[Node]:
		return []


func _make_room_with_magic_door(opened: bool) -> DummyRoom:
	var room := DummyRoom.new()
	var door: Node2D = MagicDoorScene.instantiate()
	door.name = "MagicDoor"
	door.visible = not opened
	room.add_child(door)
	return room


func test_training_level_removed_from_levels_dict() -> void:
	var main := MainScript.new()
	assert_false(main.LEVELS.has("training"), "training should not be present in LEVELS")
	main.free()


func test_level_end_trigger_detects_player_layer() -> void:
	var trigger: Area2D = LevelEndTriggerScene.instantiate()
	add_child_autoqfree(trigger)
	assert_eq(trigger.collision_mask, 2, "level-end trigger should watch the player collision layer")


func test_magic_door_open_state_is_restored_with_room_state() -> void:
	# Test room state save/restore directly on RoomManager (extracted from main.gd).
	var rm := RoomManagerScript.new()
	rm.current_room_name = "l1_bedroom"
	var first_room := _make_room_with_magic_door(true)
	rm.current_room = first_room
	rm._save_room_state()

	var second_room := _make_room_with_magic_door(false)
	rm.current_room = second_room
	var restored_door: Node2D = rm.current_room.get_node("MagicDoor")
	assert_true(restored_door.visible, "fresh room instance should start with a visible magic door")

	rm._restore_room_state("l1_bedroom")
	assert_false(restored_door.visible, "restored room should preserve opened/destroyed magic door state")
	first_room.free()
	second_room.free()
	rm.free()
