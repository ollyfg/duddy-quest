extends CharacterBody2D

## Whether this NPC is a hostile enemy (chases and attacks) or a friendly
## NPC (wanders and can be talked to).
@export var is_hostile: bool = false

## Lines shown when the player interacts with a friendly NPC.
@export var dialog_lines: Array = ["Hello, traveler!", "Good luck on your quest!"]

@export var move_speed: float = 60.0
@export var max_hp: int = 3

signal interaction_requested

const KNOCKBACK_SPEED: float = 250.0

var hp: int
var _wander_timer: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _player_ref: Node = null
var _knockback_velocity: Vector2 = Vector2.ZERO

@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	hp = max_hp
	if is_hostile:
		add_to_group("enemy")
		sprite.color = Color(0.8, 0.1, 0.1)
	else:
		add_to_group("npc")
		sprite.color = Color(0.2, 0.4, 0.9)
	$HitArea.body_entered.connect(_on_hit_area_body_entered)


func _physics_process(delta: float) -> void:
	if is_hostile and _player_ref:
		_chase_player()
	else:
		_wander(delta)

	velocity += _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_SPEED * delta * 6.0)

	move_and_slide()


## Called by the game controller to give this NPC a reference to the player.
func set_player_reference(player: Node) -> void:
	_player_ref = player


func _chase_player() -> void:
	velocity = (_player_ref.global_position - global_position).normalized() * move_speed


func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.5, 3.5)
		if randf() < 0.6:
			var angle: float = randf() * TAU
			_wander_dir = Vector2(cos(angle), sin(angle))
		else:
			_wander_dir = Vector2.ZERO
	velocity = _wander_dir * (move_speed * 0.5)


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()


func apply_knockback(direction: Vector2) -> void:
	_knockback_velocity = direction.normalized() * KNOCKBACK_SPEED


func _on_hit_area_body_entered(body: Node) -> void:
	if is_hostile and body.is_in_group("player"):
		var direction: Vector2 = ((body as Node2D).global_position - global_position).normalized()
		body.take_damage(1)
		body.apply_knockback(direction)
	elif not is_hostile and body.is_in_group("player"):
		interaction_requested.emit()
