extends "res://scripts/npc.gd"

signal phase_changed(phase_index: int)
signal boss_defeated

@export var phases: Array[Dictionary] = []

var _current_phase: int = 0
var deflect_count: int = 0
var _current_shoot_pattern: String = "single"
var _contact_damage: int = 1
## Interval in seconds between deflectable projectile shots (0 = disabled).
var _deflect_shot_interval: float = 0.0
var _deflect_shot_timer: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("boss")
	if OS.is_debug_build():
		for phase: Dictionary in phases:
			_validate_phase(phase)
	if phases.size() > 0:
		_apply_phase(phases[0])


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _deflect_shot_interval > 0.0 and _player_ref != null and not is_paused:
		_deflect_shot_timer -= delta
		if _deflect_shot_timer <= 0.0:
			_deflect_shot_timer = _deflect_shot_interval
			_fire_deflectable_projectile()


## Validate a phase dictionary in debug builds.
## Returns true if the phase is well-formed, false and emits push_error otherwise.
static func _validate_phase(phase: Dictionary) -> bool:
	if not phase.has("hp_threshold"):
		push_error("Boss phase is missing required key 'hp_threshold'")
		return false
	return true


func _apply_phase(phase: Dictionary) -> void:
	if "movement_mode" in phase:
		movement_mode = phase["movement_mode"] as MovementMode
	if "move_speed" in phase:
		move_speed = phase["move_speed"]
	if "can_shoot" in phase:
		can_shoot = phase["can_shoot"]
	if "shoot_cooldown" in phase:
		shoot_cooldown = phase["shoot_cooldown"]
		_shoot_timer = shoot_cooldown
	if "shoot_pattern" in phase:
		_current_shoot_pattern = phase["shoot_pattern"]
	if "contact_damage" in phase:
		_contact_damage = phase["contact_damage"]
	if "deflect_shot_interval" in phase:
		_deflect_shot_interval = phase["deflect_shot_interval"]
		_deflect_shot_timer = _deflect_shot_interval


func take_damage(amount: int) -> void:
	if is_queued_for_deletion():
		return
	hp -= amount
	sprite.color = DAMAGE_FLASH_COLOR
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_property(sprite, "color", HOSTILE_COLOR, 0.0)
	_check_phase_transition()
	if hp <= 0:
		boss_defeated.emit()
		queue_free()


func _check_phase_transition() -> void:
	for i in range(_current_phase + 1, phases.size()):
		if hp <= phases[i]["hp_threshold"]:
			_current_phase = i
			_apply_phase(phases[i])
			phase_changed.emit(i)
			_do_transition_flash()
			var dialog: Array = phases[i].get("transition_dialog", [])
			if dialog.size() > 0:
				dialog_lines = dialog
				interaction_requested.emit()
			break


func _do_transition_flash() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.1)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.1)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)


func _fire_projectile() -> void:
	match _current_shoot_pattern:
		"single":
			super._fire_projectile()
		"burst":
			_fire_burst()
		"arc_sweep":
			_fire_arc_sweep()


func _fire_burst() -> void:
	if projectile_scene == null or _player_ref == null:
		return
	var base_dir: Vector2 = (_player_ref.global_position - global_position).normalized()
	var angles: Array[float] = [-15.0, 0.0, 15.0]
	for angle: float in angles:
		var projectile: Node = projectile_scene.instantiate()
		var dir: Vector2 = base_dir.rotated(deg_to_rad(angle))
		projectile.setup(dir, true)
		get_tree().current_scene.add_child(projectile)
		(projectile as Node2D).global_position = global_position
		(projectile as CharacterBody2D).add_collision_exception_with(self)


func _fire_arc_sweep() -> void:
	if projectile_scene == null or _player_ref == null:
		return
	var base_dir: Vector2 = (_player_ref.global_position - global_position).normalized()
	var angles: Array[float] = [-60.0, -30.0, 0.0, 30.0, 60.0]
	for angle: float in angles:
		var projectile: Node = projectile_scene.instantiate()
		var dir: Vector2 = base_dir.rotated(deg_to_rad(angle))
		projectile.setup(dir, true)
		get_tree().current_scene.add_child(projectile)
		(projectile as Node2D).global_position = global_position
		(projectile as CharacterBody2D).add_collision_exception_with(self)


func _fire_deflectable_projectile() -> void:
	if projectile_scene == null or _player_ref == null:
		return
	var projectile: Node = projectile_scene.instantiate()
	var dir: Vector2 = (_player_ref.global_position - global_position).normalized()
	projectile.set("deflectable", true)
	projectile.setup(dir, true)
	get_tree().current_scene.add_child(projectile)
	(projectile as Node2D).global_position = global_position
	(projectile as CharacterBody2D).add_collision_exception_with(self)


## Called when a reflected projectile hits this boss.
func on_reflected_hit() -> void:
	deflect_count += 1
	if deflect_count >= 3:
		hp = 0
	take_damage(2)


## Override to use per-phase contact damage.
func _on_hit_area_body_entered(body: Node) -> void:
	if is_hostile and body.is_in_group("player"):
		var direction: Vector2 = ((body as Node2D).global_position - global_position).normalized()
		body.take_damage(_contact_damage)
		body.apply_knockback(direction)
	elif not is_hostile and body.is_in_group("player"):
		interaction_requested.emit()
