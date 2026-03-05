extends "res://scripts/boss.gd"

func _ready() -> void:
	max_hp = 10
	is_hostile = true
	detection_range = 300.0
	phases = [
		{
			"hp_threshold": 7,
			"movement_mode": MovementMode.KEEP_DISTANCE,
			"move_speed": 80.0,
			"can_shoot": true,
			"shoot_cooldown": 1.5,
			"shoot_pattern": "burst",
			"contact_damage": 1,
			"phase_label": "quirrell_phase1",
			"transition_dialog": [],
		},
		{
			"hp_threshold": 4,
			"movement_mode": MovementMode.CHASE,
			"move_speed": 100.0,
			"can_shoot": false,
			"shoot_cooldown": 999.0,
			"shoot_pattern": "single",
			"contact_damage": 2,
			"phase_label": "quirrell_phase2",
			"transition_dialog": ["The turban unravels..."],
		},
		{
			"hp_threshold": 1,
			"movement_mode": MovementMode.KEEP_DISTANCE,
			"move_speed": 60.0,
			"can_shoot": true,
			"shoot_cooldown": 2.0,
			"shoot_pattern": "arc_sweep",
			"contact_damage": 1,
			"deflect_shot_interval": 5.0,
			"phase_label": "quirrell_phase3",
			"transition_dialog": ["V-Voldemort speaks..."],
		},
	]
	super._ready()
