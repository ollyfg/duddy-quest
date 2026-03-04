extends CharacterBody2D

signal interacted
signal hp_changed(new_hp: int)
signal died

const SPEED: float = 150.0
const MELEE_COOLDOWN: float = 0.5
const SHOOT_COOLDOWN: float = 0.4
const MAX_HP: int = 5

@export var projectile_scene: PackedScene

var hp: int = MAX_HP:
	set(value):
		hp = clampi(value, 0, MAX_HP)
		hp_changed.emit(hp)

var facing: Vector2 = Vector2.DOWN

var _melee_timer: float = 0.0
var _shoot_timer: float = 0.0
var _invincible_timer: float = 0.0

@onready var melee_area: Area2D = $MeleeArea
@onready var projectile_spawn: Marker2D = $ProjectileSpawn
@onready var sprite: ColorRect = $Sprite


func _ready() -> void:
	melee_area.monitoring = false
	melee_area.monitorable = false


func _process(delta: float) -> void:
	_melee_timer = maxf(0.0, _melee_timer - delta)
	_shoot_timer = maxf(0.0, _shoot_timer - delta)
	_invincible_timer = maxf(0.0, _invincible_timer - delta)


func _physics_process(_delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		direction.y -= 1.0
	if Input.is_action_pressed("move_down"):
		direction.y += 1.0
	if Input.is_action_pressed("move_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("move_right"):
		direction.x += 1.0

	if direction != Vector2.ZERO:
		facing = direction.normalized()
		velocity = direction.normalized() * SPEED
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if Input.is_action_just_pressed("melee_attack"):
		_perform_melee()
	if Input.is_action_just_pressed("ranged_attack"):
		_perform_ranged()
	if Input.is_action_just_pressed("interact"):
		interacted.emit()


func _perform_melee() -> void:
	if _melee_timer > 0.0:
		return
	_melee_timer = MELEE_COOLDOWN
	melee_area.position = facing * 24.0
	melee_area.monitoring = true
	melee_area.monitorable = true
	await get_tree().create_timer(0.15).timeout
	melee_area.monitoring = false
	melee_area.monitorable = false


func _perform_ranged() -> void:
	if _shoot_timer > 0.0 or projectile_scene == null:
		return
	_shoot_timer = SHOOT_COOLDOWN
	var proj: CharacterBody2D = projectile_scene.instantiate()
	# Call setup before add_child so _ready() on the projectile sees the correct values.
	proj.setup(facing, false)
	get_parent().add_child(proj)
	proj.global_position = projectile_spawn.global_position


func take_damage(amount: int) -> void:
	if _invincible_timer > 0.0:
		return
	_invincible_timer = 1.0
	hp -= amount
	if hp <= 0:
		died.emit()
		queue_free()


func _on_melee_area_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
