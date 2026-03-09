# Issue 3 — Extract shared gameplay constants into a config resource

## Problem

Gameplay-tuning values are scattered across scripts as inline literals:

| Value | Location | Example |
|---|---|---|
| Melee range | `player.gd:219,304` | `24.0` |
| Melee duration | `player.gd:224` | `0.15` |
| Rage AoE radius | `player.gd:315` | `64.0` |
| Knockback speed | `player.gd:16`, `npc.gd:118` | `400.0`, `500.0` |
| Knockback decay | `player.gd:17`, `npc.gd:119` | `6.0` multiplier |
| Room bounds | `npc.gd:120-121` | `640 × 480` |
| Patrol threshold | `npc.gd:129` | `8.0` |
| Wander probability | `npc.gd:~312` | `0.6` |
| Wander speed factor | `npc.gd:~382` | `0.5` |
| Camera limit sentinel | `cinematic_player.gd:7` | `100000` |

Changing any single value requires grepping the codebase to find all
related occurrences. Some constants are duplicated with slightly different
values (e.g. knockback speed 400 vs 500), making it unclear which is
intentional.

## Suggested approach

Create `scripts/config.gd` (or a Godot `Resource` subclass) with clearly
named constants grouped by system:

```gdscript
class_name GameConfig

# -- Movement --
const GRID_SIZE: int = 16
const ROOM_WIDTH: float = 640.0
const ROOM_HEIGHT: float = 480.0

# -- Melee --
const MELEE_RANGE: float = 24.0
const MELEE_ACTIVE_DURATION: float = 0.15

# -- Knockback --
const PLAYER_KNOCKBACK_SPEED: float = 400.0
const NPC_KNOCKBACK_SPEED: float = 500.0
const KNOCKBACK_DECAY_MULTIPLIER: float = 6.0

# -- Rage --
const RAGE_AOE_RADIUS: float = 64.0

# etc.
```

Then replace inline literals with `GameConfig.MELEE_RANGE` everywhere.

## Acceptance criteria

- [ ] No raw numeric literal is used where a named constant exists
- [ ] Knockback values are consolidated — intentional differences are
      documented in the config
- [ ] Existing tests and `check_rooms.py` / `check_alignment.py` pass
- [ ] A note in the README points designers to `config.gd` for tuning
