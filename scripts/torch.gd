extends StaticBody2D

@export var light_duration: float = 5.0

@onready var light_source: LightSource = $LightSource
@onready var sprite: ColorRect = $Sprite

const LIT_COLOR: Color = Color(1.0, 0.6, 0.1)
const UNLIT_COLOR: Color = Color(0.5, 0.5, 0.5)


func _ready() -> void:
	add_to_group("lightable")
	light_source.duration = light_duration
	light_source.lit_changed.connect(_on_lit_changed)
	sprite.color = UNLIT_COLOR


func on_hit() -> void:
	light_source.light_up()


func _on_lit_changed(lit: bool) -> void:
	sprite.color = LIT_COLOR if lit else UNLIT_COLOR
