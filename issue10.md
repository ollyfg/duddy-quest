# Issue 10 — Eliminate duplicate damage-flash and knockback code

## Problem

Damage feedback (colour flash + knockback) is implemented independently
in both `player.gd` and `npc.gd`:

### Damage flash
```gdscript
# player.gd ~line 245
var tw := create_tween()
tw.tween_property($Sprite, "modulate", Color.WHITE, 0.15)

# npc.gd ~line 413
var tw := create_tween()
tw.tween_property($Sprite, "modulate", Color.WHITE, 0.15)
```

### Knockback
```gdscript
# player.gd
const KNOCKBACK_SPEED: float = 400.0
_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO,
    KNOCKBACK_SPEED * delta * 6.0)

# npc.gd
const KNOCKBACK_SPEED: float = 500.0
_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO,
    KNOCKBACK_SPEED * delta * KNOCKBACK_DECAY_MULTIPLIER)
```

If the damage flash timing, colour, or knockback curve is tweaked, both
files must be updated in sync. The knockback speeds are already
inconsistent (400 vs 500) — it's unclear whether this is intentional.

## Suggested approach

Extract into a shared utility:

```gdscript
# scripts/combat_utils.gd
class_name CombatUtils

static func apply_knockback(body: CharacterBody2D, direction: Vector2,
        speed: float = 400.0) -> void:
    body.set_meta("_knockback_velocity", direction.normalized() * speed)

static func decay_knockback(body: CharacterBody2D, delta: float,
        decay_rate: float = 6.0) -> Vector2:
    var kb: Vector2 = body.get_meta("_knockback_velocity", Vector2.ZERO)
    kb = kb.move_toward(Vector2.ZERO, kb.length() * decay_rate * delta)
    body.set_meta("_knockback_velocity", kb)
    return kb

static func flash_damage(sprite: Node, color: Color = Color.RED,
        duration: float = 0.15) -> void:
    sprite.modulate = color
    var tw := sprite.create_tween()
    tw.tween_property(sprite, "modulate", Color.WHITE, duration)
```

Both `player.gd` and `npc.gd` call through these utils, keeping
behaviour consistent and tuneable from one place.

## Acceptance criteria

- [ ] Damage flash logic exists in exactly one place
- [ ] Knockback decay logic exists in exactly one place
- [ ] Intentional speed/timing differences are documented as explicit
      parameters, not magic numbers
- [ ] Player and NPC damage feedback visually unchanged
