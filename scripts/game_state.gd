extends Node

## Persists data that needs to survive scene changes (e.g. selected level).
var selected_level: String = "training"
var completed_levels: Array[String] = []


func mark_complete(level_name: String) -> void:
	if level_name not in completed_levels:
		completed_levels.append(level_name)


func is_complete(level_name: String) -> bool:
	return level_name in completed_levels
