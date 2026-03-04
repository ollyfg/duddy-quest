extends CharacterBody2D

signal hp_changed(new_hp: int)
signal died

const SPEED: float = 150.0
const MELEE_COOLDOWN: float = 0.5
const SHOOT_COOLDOWN: float = 0.4
const MAX_HP: int = 5
const KNOCKBACK_SPEED: float = 300.0
const GRID_SIZE: int = 16
const KNOCKBACK_THRESHOLD: float = 5.0
const GRID_SNAP_THRESHOLD: float = 2.0

@export var projectile_scene: PackedScene

var hp: int = MAX_HP:
	set(value):
		hp = clampi(value, 0, MAX_HP)
		hp_changed.emit(hp)

var facing: Vector2 = Vector2.DOWN

var is_in_dialog: bool = false

var _melee_timer: float = 0.0
var _shoot_timer: float = 0.0
var _invincible_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _moving: bool = false
var _target_pos: Vector2 = Vector2.ZERO
var _step_start: Vector2 = Vector2.ZERO

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


func _physics_process(delta: float) -> void:
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_SPEED * delta * 6.0)

	if is_in_dialog:
		velocity = Vector2.ZERO
		_moving = false
		move_and_slide()
		return

	if _knockback_velocity.length() > KNOCKBACK_THRESHOLD:
		# Knocked back: bypass grid, free movement.
		velocity = _knockback_velocity
		_moving = false
		move_and_slide()
	else:
		if _moving:
			var to_target: Vector2 = _target_pos - global_position
			if to_target.length() < GRID_SNAP_THRESHOLD:
				global_position = _target_pos
				velocity = Vector2.ZERO
				_moving = false
			else:
				velocity = to_target.normalized() * SPEED
		else:
			velocity = Vector2.ZERO
			var input_dir := Vector2.ZERO
			if Input.is_action_pressed("move_up"):
				input_dir = Vector2.UP
			elif Input.is_action_pressed("move_down"):
				input_dir = Vector2.DOWN
			elif Input.is_action_pressed("move_left"):
				input_dir = Vector2.LEFT
			elif Input.is_action_pressed("move_right"):
				input_dir = Vector2.RIGHT

			if input_dir != Vector2.ZERO:
				facing = input_dir
				var snapped: Vector2 = global_position.snapped(Vector2.ONE * GRID_SIZE)
				_step_start = snapped
				_target_pos = snapped + input_dir * GRID_SIZE
				global_position = snapped
				_moving = true

		move_and_slide()
		if _moving and get_slide_collision_count() > 0:
			# Hit a wall mid-step: snap back to step start.
			global_position = _step_start
			velocity = Vector2.ZERO
			_moving = false

	if Input.is_action_just_pressed("melee_attack"):
		_perform_melee()
	if Input.is_action_just_pressed("ranged_attack"):
		_perform_ranged()


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
	var projectile: CharacterBody2D = projectile_scene.instantiate()
	# Call setup before add_child so _ready() on the projectile sees the correct values.
	projectile.setup(facing, false)
	get_parent().add_child(projectile)
	projectile.global_position = projectile_spawn.global_position


func take_damage(amount: int) -> void:
	if _invincible_timer > 0.0:
		return
	_invincible_timer = 1.0
	hp -= amount
	if hp <= 0:
		died.emit()
		queue_free()


func apply_knockback(direction: Vector2) -> void:
	_knockback_velocity = direction.normalized() * KNOCKBACK_SPEED


func _on_melee_area_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
	if body.has_method("apply_knockback"):
		var direction: Vector2 = ((body as Node2D).global_position - global_position).normalized()
		body.apply_knockback(direction)
