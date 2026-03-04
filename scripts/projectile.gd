extends CharacterBody2D

const SPEED: float = 300.0
const LIFETIME: float = 2.0

## Direction the projectile travels (normalised).
var direction: Vector2 = Vector2.RIGHT
## True when fired by an enemy; false when fired by the player.
var is_enemy_projectile: bool = false

var _lifetime: float = LIFETIME

@onready var sprite: ColorRect = $Sprite


## Initialise direction and ownership.  Must be called before add_child so
## that _ready() can apply the correct colour.
func setup(dir: Vector2, enemy: bool) -> void:
	direction = dir.normalized()
	is_enemy_projectile = enemy


func _ready() -> void:
	sprite.color = Color(0.9, 0.2, 0.2) if is_enemy_projectile else Color(1.0, 0.9, 0.1)


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	velocity = direction * SPEED
	move_and_slide()
	# Despawn on hitting any static obstacle.
	if get_slide_collision_count() > 0:
		queue_free()


func _on_hit_area_body_entered(body: Node) -> void:
	if is_enemy_projectile and body.is_in_group("player"):
		body.take_damage(1)
		queue_free()
	elif not is_enemy_projectile and body.is_in_group("enemy"):
		body.take_damage(1)
		queue_free()
