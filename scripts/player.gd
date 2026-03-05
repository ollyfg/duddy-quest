extends CharacterBody2D

signal hp_changed(new_hp: int)
signal died
signal wand_acquired
signal keys_changed(count: int)
signal rage_attack
signal rage_changed(value: float)

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
const RAGE_COLOR: Color = Color(1.0, 0.4, 0.0)
const RAGE_PER_SWING: float = 0.2
const RAGE_DECAY_RATE: float = 0.05
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

var rage: float = 0.0

func has_key(key_id: String) -> bool:
	return key_id in inventory

func remove_key(key_id: String) -> void:
	inventory.erase(key_id)
	keys_changed.emit(inventory.size())

var facing: Vector2 = Vector2.DOWN

var is_in_dialog: bool = false:
	set(value):
		if is_in_dialog and not value:
			_dialog_closing_frame = true
		is_in_dialog = value
var cinematic_mode: bool = false

var _melee_timer: float = 0.0
var _shoot_timer: float = 0.0
var _invincible_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _moving: bool = false
var _target_pos: Vector2 = Vector2.ZERO
var _step_start: Vector2 = Vector2.ZERO
## Set when dialog closes so attack input consumed to dismiss dialog is not
## forwarded to the player as an attack on the same physics frame.
var _dialog_closing_frame: bool = false

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
	if rage > 0.0:
		rage = maxf(0.0, rage - RAGE_DECAY_RATE * delta)
		rage_changed.emit(rage)


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
				var desired := Vector2(
					sign(input_dir.x) * GRID_SIZE if input_dir.x != 0.0 else 0.0,
					sign(input_dir.y) * GRID_SIZE if input_dir.y != 0.0 else 0.0
				)
				# Pre-test the step so walls are avoided before committing.
				# For diagonal input this enables wall-sliding along each axis.
				var step := _choose_step(snapped, desired)
				if step != Vector2.ZERO:
					_step_start = snapped
					_target_pos = snapped + step
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

	# Guard attacks: suppress on the frame dialog closes so the key-press that
	# dismissed the dialog does not also fire a melee swing or ranged shot.
	if not _dialog_closing_frame:
		if Input.is_action_just_pressed("melee_attack"):
			_perform_melee()
		if Input.is_action_just_pressed("ranged_attack"):
			_perform_ranged()
	_dialog_closing_frame = false


## Returns the best grid step from `from` toward `desired`, with wall-sliding.
## Tests the full step first; if blocked by a non-pushable static body and the
## input is diagonal, each axis is tried individually so the player slides
## along walls instead of stopping dead.  Returns Vector2.ZERO when fully
## blocked.
func _choose_step(from: Vector2, desired: Vector2) -> Vector2:
	var xform := get_global_transform()
	xform.origin = from
	var coll := KinematicCollision2D.new()
	if not test_move(xform, desired, coll):
		return desired  # Full path is clear.
	# If the obstacle is a pushable block, commit anyway so the push fires.
	var collider := coll.get_collider()
	if collider != null and collider.is_in_group("pushable"):
		return desired
	# Diagonal input blocked: try each axis alone (wall-slide).
	if desired.x != 0.0 and desired.y != 0.0:
		if not test_move(xform, Vector2(desired.x, 0.0)):
			return Vector2(desired.x, 0.0)
		if not test_move(xform, Vector2(0.0, desired.y)):
			return Vector2(0.0, desired.y)
	return Vector2.ZERO  # Completely blocked.


func _perform_melee() -> void:
	if _melee_timer > 0.0:
		return
	_melee_timer = MELEE_COOLDOWN
	melee_area.position = facing * 24.0
	melee_area.monitoring = true
	melee_area.monitorable = true
	melee_sprite.visible = true
	_add_rage(RAGE_PER_SWING)
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
	# Deflect projectiles before applying melee damage.
	if body.get("deflectable") == true and body.get("_reflected") == false:
		body.reflect()
		return
	if body.has_method("on_hit"):
		body.on_hit()
	if body.has_method("take_damage"):
		body.take_damage(1)
	if body.has_method("apply_knockback"):
		var direction: Vector2 = ((body as Node2D).global_position - global_position).normalized()
		body.apply_knockback(direction)


func _add_rage(amount: float) -> void:
	rage = minf(1.0, rage + amount)
	rage_changed.emit(rage)
	if rage >= 1.0:
		rage = 0.0
		rage_changed.emit(rage)
		rage_attack.emit()
		_trigger_rage_attack()


func _trigger_rage_attack() -> void:
	# Spin through all four facing directions for visual effect.
	for dir: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		melee_area.position = dir * 24.0
		melee_sprite.visible = true
		sprite.color = RAGE_COLOR
		await get_tree().create_timer(0.05).timeout
	melee_sprite.visible = false
	var tween := create_tween()
	tween.tween_property(sprite, "color", PLAYER_COLOR, 0.2)
	# Use a direct physics query so static bodies are detected immediately.
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 64.0
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 1
	# Exclude the player itself from the results.
	query.exclude = [get_rid()]
	var results: Array[Dictionary] = space.intersect_shape(query)
	for result: Dictionary in results:
		var body: Node = result["collider"]
		_on_rage_area_body_entered(body)


func _on_rage_area_body_entered(body: Node) -> void:
	## "breakable" — destructible objects (doors, crates, etc.) with on_rage_attack().
	## "rage_target" — reserved for future objects with special rage interactions.
	if body.is_in_group("rage_target") or body.is_in_group("breakable"):
		if body.has_method("on_rage_attack"):
			body.on_rage_attack()
	if body.has_method("take_damage"):
		body.take_damage(2)
	if body.has_method("apply_knockback"):
		var direction: Vector2 = ((body as Node2D).global_position - global_position).normalized()
		body.apply_knockback(direction)
