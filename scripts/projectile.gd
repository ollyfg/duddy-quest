extends CharacterBody2D

signal projectile_missed

const SPEED: float = 300.0
const LIFETIME: float = 2.0

## Direction the projectile travels (normalised).
var direction: Vector2 = Vector2.RIGHT
## True when fired by an enemy; false when fired by the player.
var is_enemy_projectile: bool = false
## When true the player can deflect this projectile with a melee attack.
@export var deflectable: bool = false
var _reflected: bool = false
var _hit_something: bool = false

var _lifetime: float = LIFETIME

@onready var sprite: ColorRect = $Sprite


## Initialise direction and ownership.  Must be called before add_child so
## that _ready() can apply the correct colour.
func setup(dir: Vector2, enemy: bool) -> void:
	direction = dir.normalized()
	is_enemy_projectile = enemy


func _ready() -> void:
	if deflectable:
		sprite.color = Color(1.0, 0.65, 0.0)
	elif is_enemy_projectile:
		sprite.color = Color(0.9, 0.2, 0.2)
	else:
		sprite.color = Color(1.0, 0.9, 0.1)


## Reverse this projectile's direction and mark it as reflected.
## A reflected projectile deals double damage and cannot be deflected again.
func reflect() -> void:
	if _reflected:
		return
	_reflected = true
	direction = -direction
	is_enemy_projectile = false
	sprite.color = Color(0.0, 1.0, 0.8)


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		if not _hit_something and not is_enemy_projectile:
			projectile_missed.emit()
		queue_free()
		return
	velocity = direction * SPEED
	move_and_slide()
	# Despawn on hitting any static obstacle; notify lightable bodies.
	if get_slide_collision_count() > 0:
		_hit_something = true
		for i in range(get_slide_collision_count()):
			var col := get_slide_collision(i)
			var collider := col.get_collider()
			if collider and collider.has_method("on_hit"):
				collider.on_hit()
		queue_free()


func _on_hit_area_body_entered(body: Node) -> void:
	if is_enemy_projectile and body.is_in_group("player"):
		_hit_something = true
		body.take_damage(1)
		queue_free()
	elif not is_enemy_projectile and body.is_in_group("enemy"):
		_hit_something = true
		if _reflected and body.has_method("on_reflected_hit"):
			body.on_reflected_hit()
		else:
			body.take_damage(1)
		queue_free()
	elif not is_enemy_projectile and body.has_method("on_hit"):
		_hit_something = true
		body.on_hit()
		queue_free()
