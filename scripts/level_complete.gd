extends CanvasLayer

signal continue_pressed

@export var level_title: String = ""

@onready var _title_label: Label = $TitleLabel
@onready var _continue_label: Label = $ContinueLabel


func _ready() -> void:
	_title_label.text = level_title if level_title != "" else "Level Complete"
	# Accept any confirm-style input to dismiss.
	set_process(true)


func _process(_delta: float) -> void:
	if (Input.is_action_just_pressed("melee_attack")
			or Input.is_action_just_pressed("ranged_attack")
			or Input.is_action_just_pressed("interact")):
		set_process(false)
		continue_pressed.emit()
