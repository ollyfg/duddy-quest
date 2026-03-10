extends "res://scripts/boss.gd"

func _ready() -> void:
	max_hp = 6
	is_hostile = true
	detection_range = 500.0
	# Phase 1 (HP 6–4): Draco keeps distance and fires single jinxes.
	# Phase 2 (HP 3–0): Draco charges and fires burst of three jinxes.
	phases = [
		{
			"hp_threshold": 3,
			"movement_mode": MovementMode.KEEP_DISTANCE,
			"move_speed": 70.0,
			"can_shoot": true,
			"shoot_cooldown": 2.0,
			"shoot_pattern": "single",
			"contact_damage": 1,
		},
		{
			"hp_threshold": 0,
			"movement_mode": MovementMode.CHASE,
			"move_speed": 100.0,
			"can_shoot": true,
			"shoot_cooldown": 1.2,
			"shoot_pattern": "burst",
			"contact_damage": 1,
		},
	]
	super._ready()


## Override to prevent immediate queue_free so the defeat cinematic can
## animate Draco fleeing before the node is removed.
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
		is_hostile = false
		is_paused = true
		boss_defeated.emit()
		# The defeat cinematic (main._play_draco_defeat_cinematic) will
		# call queue_free() after the flee animation completes.
