extends Node

## Persists data that needs to survive scene changes (e.g. selected level).
var selected_level: String = "training"
var completed_levels: Array[String] = []


func _ready() -> void:
	_setup_emoji_font()


## Sets up a global theme with an emoji-capable font (DejaVu Sans + NotoColorEmoji
## fallback) so that Unicode arrows (↑↓←→), health dots (●○), and emoji (🗝🏏🪄)
## all render correctly throughout the game.
func _setup_emoji_font() -> void:
	var main_font: FontFile = load("res://assets/fonts/DejaVuSans.ttf")
	var emoji_font: FontFile = load("res://assets/fonts/NotoColorEmoji.ttf")
	main_font.fallbacks = [emoji_font]
	var theme := Theme.new()
	theme.default_font = main_font
	get_tree().root.theme = theme


func mark_complete(level_name: String) -> void:
	if level_name not in completed_levels:
		completed_levels.append(level_name)


func is_complete(level_name: String) -> bool:
	return level_name in completed_levels
