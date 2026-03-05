extends Node2D
class_name LightSource

signal lit_changed(is_lit: bool)

@export var radius: float = 80.0
@export var duration: float = 0.0
@export var starts_lit: bool = false
@export var lit_color: Color = Color(1.0, 0.85, 0.4, 0.35)

var is_lit: bool = false
var _duration_timer: float = 0.0

@onready var point_light: PointLight2D = $PointLight2D


func _ready() -> void:
	add_to_group("light_source")
	add_to_group("lightable")
	point_light.enabled = false
	point_light.color = lit_color
	point_light.texture_scale = radius / 64.0
	if starts_lit:
		light_up()


func _process(delta: float) -> void:
	if is_lit and duration > 0.0:
		_duration_timer -= delta
		if _duration_timer <= 0.0:
			extinguish()


func light_up() -> void:
	is_lit = true
	_duration_timer = duration
	point_light.enabled = true
	lit_changed.emit(true)


func extinguish() -> void:
	is_lit = false
	point_light.enabled = false
	lit_changed.emit(false)


func on_hit() -> void:
	light_up()


## Returns true if the given point is within the radius of any lit LightSource.
static func is_point_lit(point: Vector2, scene_tree: SceneTree) -> bool:
	for node in scene_tree.get_nodes_in_group("light_source"):
		if node is LightSource and node.is_lit and node.global_position.distance_to(point) <= node.radius:
			return true
	return false
