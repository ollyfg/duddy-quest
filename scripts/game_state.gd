extends Node

## Persists data that needs to survive scene changes (e.g. selected level).

## Current game version. Bump this on every new deploy.
const VERSION: String = "0.24.0"

var selected_level: String = "level_1"
var completed_levels: Array[String] = []

## All valid one-off story flag names. set_flag() warns if a name is not listed.
const KNOWN_FLAGS: Array[String] = [
	"l1_bedroom_door_hint_shown",
	"l1_hallway_intro_shown",
	"l1_street_intro_shown",
	"mrs_figg_met",
]

## Generic boolean flags for one-off story events.
var flags: Dictionary = {}


func set_flag(flag_name: String) -> void:
	if flag_name not in KNOWN_FLAGS:
		push_warning("GameState.set_flag: unknown flag '%s'" % flag_name)
	flags[flag_name] = true


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


## Clears all flags whose names start with the given prefix.
## Use e.g. clear_level_flags("l1_") to reset all Level 1 flags.
func clear_level_flags(prefix: String) -> void:
	for key: String in flags.keys():
		if key.begins_with(prefix):
			flags.erase(key)


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
