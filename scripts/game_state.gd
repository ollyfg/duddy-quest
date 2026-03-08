extends Node

## Persists data that needs to survive scene changes (e.g. selected level).

## Current game version. Bump this on every new deploy.
const VERSION: String = "0.9.0"

var selected_level: String = "level_1"
var completed_levels: Array[String] = []

## Generic boolean flags for one-off story events.
var flags: Dictionary = {}
## Set to true once the bedroom door hint dialog has been shown.
var l1_bedroom_door_hint_shown: bool = false


func set_flag(flag_name: String) -> void:
	flags[flag_name] = true


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func _ready() -> void:
	_setup_emoji_font()


## Sets up a global theme with DejaVu Sans as the default font so that health
## dots (●○) and other Latin/geometric characters render correctly throughout
## the game.
func _setup_emoji_font() -> void:
	var main_font: FontFile = preload("res://assets/fonts/DejaVuSans.ttf")
	var theme := Theme.new()
	theme.default_font = main_font
	# Explicitly set the font for common control types so the font is used
	# even when a control's theme lookup reaches a type-specific entry
	# before falling back to default_font.
	for control_type: String in ["Label", "Button", "RichTextLabel"]:
		theme.set_font("font", control_type, main_font)
	get_tree().root.theme = theme


func mark_complete(level_name: String) -> void:
	if level_name not in completed_levels:
		completed_levels.append(level_name)


func is_complete(level_name: String) -> bool:
	return level_name in completed_levels
