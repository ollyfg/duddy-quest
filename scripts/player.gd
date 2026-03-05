extends CharacterBody2D

signal hp_changed(new_hp: int)
signal died
signal wand_acquired
signal keys_changed(count: int)

const SPEED: float = 150.0
const MELEE_COOLDOWN: float = 0.5
const SHOOT_COOLDOWN: float = 0.4
const MAX_HP: int = 5
const KNOCKBACK_SPEED: float = 300.0
const GRID_SIZE: int = 16
const KNOCKBACK_THRESHOLD: float = 5.0
const GRID_SNAP_THRESHOLD: float = 2.0
const PLAYER_COLOR: Color = Color(0, 0.75, 0.2)
const DAMAGE_FLASH_COLOR: Color = Color(1.0, 0.2, 0.2)
## Dot-product threshold below which a collision normal is considered to be
## opposing the intended step direction (i.e. actually blocking movement).
const COLLISION_BLOCKING_THRESHOLD: float = -0.3

@export var projectile_scene: PackedScene

var hp: int = MAX_HP:
	set(value):
		hp = clampi(value, 0, MAX_HP)
		hp_changed.emit(hp)

var has_wand: bool = false:
	set(value):
		has_wand = value
		if value:
			wand_acquired.emit()

## Keys currently held by the player.  Persists across room transitions.
var inventory: Array[String] = []

func has_key(key_id: String) -> bool:
	return key_id in inventory

func remove_key(key_id: String) -> void:
	inventory.erase(key_id)
	keys_changed.emit(inventory.size())

var facing: Vector2 = Vector2.DOWN

var is_in_dialog: bool = false
var cinematic_mode: bool = false

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
@onready var melee_sprite: ColorRect = $MeleeArea/MeleeSprite
@onready var camera: Camera2D = $Camera2D


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

	if cinematic_mode:
		velocity = Vector2.ZERO
		_moving = false
		move_and_slide()
		return

	if _knockback_velocity.length() > KNOCKBACK_THRESHOLD:
		# Knocked back: bypass grid, free movement.
		velocity = _knockback_velocity
		_moving = false
		move_and_slide()
		# Feed the post-collision (wall-slid) velocity back so the player
		# slides along walls instead of being pushed into them.
		_knockback_velocity = velocity
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
				input_dir.y -= 1.0
			if Input.is_action_pressed("move_down"):
				input_dir.y += 1.0
			if Input.is_action_pressed("move_left"):
				input_dir.x -= 1.0
			if Input.is_action_pressed("move_right"):
				input_dir.x += 1.0

			if input_dir != Vector2.ZERO:
				facing = Vector2(sign(input_dir.x), sign(input_dir.y)).normalized()
				var snapped: Vector2 = global_position.snapped(Vector2.ONE * GRID_SIZE)
				_step_start = snapped
				# Each pressed axis moves by one full grid step (supports diagonal).
				_target_pos = snapped + Vector2(
					(sign(input_dir.x) * GRID_SIZE) if input_dir.x != 0.0 else 0.0,
					(sign(input_dir.y) * GRID_SIZE) if input_dir.y != 0.0 else 0.0
				)
				global_position = snapped
				_moving = true

		move_and_slide()
		if _moving and get_slide_collision_count() > 0:
			# Only snap back if a collision is actually opposing the step direction
			# (avoids false positives when touching a perpendicular wall).
			var step_dir := (_target_pos - _step_start).normalized()
			var blocked := false
			for i: int in range(get_slide_collision_count()):
				if get_slide_collision(i).get_normal().dot(step_dir) < COLLISION_BLOCKING_THRESHOLD:
					blocked = true
					break
			if blocked:
				# Check if the blocking body is a pushable block.
				var push_dir := (_target_pos - _step_start).normalized()
				for i: int in range(get_slide_collision_count()):
					var collider := get_slide_collision(i).get_collider()
					if collider and collider.is_in_group("pushable"):
						collider.try_push(push_dir)
						break
				# Snap back to step start regardless (block handles its own move).
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
	melee_sprite.visible = true
	await get_tree().create_timer(0.15).timeout
	melee_area.monitoring = false
	melee_area.monitorable = false
	melee_sprite.visible = false


func _perform_ranged() -> void:
	if _shoot_timer > 0.0 or projectile_scene == null or not has_wand:
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
	sprite.color = DAMAGE_FLASH_COLOR
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_property(sprite, "color", PLAYER_COLOR, 0.0)
	if hp <= 0:
		died.emit()
		queue_free()


func apply_knockback(direction: Vector2) -> void:
	_knockback_velocity = direction.normalized() * KNOCKBACK_SPEED


## Cancels any in-progress grid step and clears knockback.
## Call this whenever the player is teleported to a new position (e.g. room
## transition) so stale movement state from the old room does not carry over.
func cancel_movement() -> void:
	_moving = false
	_target_pos = global_position
	_step_start = global_position
	velocity = Vector2.ZERO
	_knockback_velocity = Vector2.ZERO


func set_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.position.x + rect.size.x)
	camera.limit_bottom = int(rect.position.y + rect.size.y)


func _on_melee_area_body_entered(body: Node) -> void:
	if body.has_method("on_hit"):
		body.on_hit()
	if body.has_method("take_damage"):
		body.take_damage(1)
	if body.has_method("apply_knockback"):
		var direction: Vector2 = ((body as Node2D).global_position - global_position).normalized()
		body.apply_knockback(direction)
