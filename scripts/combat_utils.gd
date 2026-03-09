## CombatUtils — shared helpers for damage feedback and knockback.
## Both Player and NPC route through these functions so that visual timing
## and physics feel can be tuned in one place.

class_name CombatUtils


## Flash a ColorRect sprite to `flash_color` then tween it back to
## `base_color` after `duration` seconds.  The sprite itself is used as the
## tween owner so the tween is freed automatically when the sprite is freed.
static func flash_damage(sprite: ColorRect, flash_color: Color,
		base_color: Color, duration: float = 0.2) -> void:
	sprite.color = flash_color
	var tween := sprite.create_tween()
	tween.tween_interval(duration)
	tween.tween_property(sprite, "color", base_color, 0.0)


## Decay a knockback velocity by `speed * delta * decay_rate` toward zero
## and return the updated velocity.  Keeping this logic here ensures player
## and NPC knockback feel the same even though their initial speeds differ.
static func decay_knockback(velocity: Vector2, speed: float, delta: float,
		decay_rate: float) -> Vector2:
	return velocity.move_toward(Vector2.ZERO, speed * delta * decay_rate)
