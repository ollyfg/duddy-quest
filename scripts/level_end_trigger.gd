extends Area2D

signal level_end_reached

@export var end_cutscene_slides: Array = []
@export var next_level: String = ""
## When non-empty, the trigger only fires if GameState has this flag set.
@export var requires_flag: String = ""

var _triggered: bool = false


func _ready() -> void:
	add_to_group("level_end")
	set_process(false)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _triggered:
		return
	if body.is_in_group("player"):
		if requires_flag != "" and not GameState.has_flag(requires_flag):
			# Flag not yet set.  Start polling so we catch the moment it becomes
			# set while the player is already overlapping the trigger area (e.g.
			# the player is inside the area when the defeat cinematic sets the
			# flag, so body_entered will not fire again).
			set_process(true)
			return
		_fire()


## Poll each frame in case the player is already overlapping when the flag
## becomes set (e.g. after a defeat cinematic completes inside the trigger area).
func _process(_delta: float) -> void:
	if _triggered:
		set_process(false)
		return
	if requires_flag != "" and not GameState.has_flag(requires_flag):
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_fire()
			return


func _fire() -> void:
	_triggered = true
	set_process(false)
	level_end_reached.emit()
