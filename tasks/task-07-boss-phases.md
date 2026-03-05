# Task 07 — Multi-Phase Boss Fight Framework

## Summary
Extend the NPC system to support multi-phase bosses: enemies that transition
through distinct phases (each with different movement patterns, attacks, and
visuals) when they reach HP thresholds.

The primary use is the **Level 4 Quirrell / Voldemort boss fight**, which has
three distinct phases, but the framework should be generic enough to reuse.

---

## Motivation (from the plot — Level 4)

> **Phase 1 — Quirrell at distance:** hurls jinxes in rapid bursts; player
> dodges and counters with wand-blasts.
>
> **Phase 2 — Quirrell up close:** desperate and flailing; uses turban as a
> bludgeoning weapon; close-range Smeltings stick combat.
>
> **Phase 3 — The reveal:** turban unravels; Voldemort's face screams and blasts
> raw dark energy in wide arcing sweeps.  Player dodges arcs and returns fire.
> Periodically Voldemort's face targets Dudley with a focused curse that must be
> deflected with a precisely timed Smeltings stick swing (working as accidental
> magic).  Three successful deflections end the fight.

---

## Acceptance Criteria

### Phase Definition

1. A boss NPC (extending `npc.gd` **or** a new `boss.gd` that `extends npc.gd`)
   holds a list of phase descriptors:
   ```gdscript
   @export var phases: Array[Dictionary] = []
   ```
   Each phase Dictionary:
   ```gdscript
   {
     "hp_threshold": int,        # enter this phase when hp drops to this value
     "movement_mode": int,       # MovementMode enum value
     "move_speed": float,
     "can_shoot": bool,
     "shoot_cooldown": float,
     "shoot_pattern": String,    # "single" | "burst" | "arc_sweep"
     "contact_damage": int,      # damage dealt on body contact
     "phase_label": String,      # e.g. "quirrell_phase1" — used for visuals/SFX
     "transition_dialog": Array, # optional lines shown when entering this phase
   }
   ```

2. `boss.gd` monitors `hp` and transitions to the next phase when
   `hp <= phases[next_phase_index]["hp_threshold"]`.

3. On phase transition:
   - Apply the new phase's stats (`move_speed`, `can_shoot`, etc.).
   - Play a brief invincibility flash (existing damage-flash tween).
   - Show `transition_dialog` lines if any (using the dialog box from `main.gd`).
   - Emit `signal phase_changed(phase_index: int)`.

### Shoot Patterns

4. Add three shoot patterns to the boss:
   - `"single"` — fire one projectile toward the player (existing behaviour).
   - `"burst"` — fire three projectiles in a tight spread (±15°) toward the player.
   - `"arc_sweep"` — fire a slow-moving projectile that sweeps a wide arc (used
     by Voldemort face in Phase 3).

### Deflection Mechanic (Phase 3 / Quirrell)

5. Some projectiles may be flagged `"deflectable": true`.  When the player
   performs a melee attack (`_perform_melee`) and the melee area overlaps a
   deflectable projectile, the projectile's direction is reversed (reflected
   back at the boss).  A reflected projectile deals double damage and is
   flagged `"reflected": true` so the boss cannot deflect it again.

6. `boss.gd` tracks `var deflect_count: int`.  When a reflected projectile hits
   the boss, `deflect_count += 1`.  After three successful deflections the boss
   is instantly defeated (hp set to 0) regardless of remaining HP.

### Defeat and Completion

7. When the boss's HP reaches 0 (or `deflect_count >= 3`), the boss emits
   `signal boss_defeated` before calling `queue_free()`.

8. `main.gd` connects `boss_defeated` and feeds it into the level-completion
   path (Task 06).

### Quirrell Specific Boss Scene

9. Create `scenes/boss_quirrell.tscn` and `scripts/boss_quirrell.gd` that
   configures the three-phase Quirrell/Voldemort fight using the framework above.
   Phase configurations:
   - **Phase 1** (hp ≥ 7): KEEP_DISTANCE mode, shoots `burst` at cooldown 1.5 s.
   - **Phase 2** (hp ≥ 4): CHASE mode, no shooting, contact damage 2, melee
     attack pattern.
   - **Phase 3** (hp ≥ 1): KEEP_DISTANCE mode, shoots `arc_sweep` at cooldown
     2.0 s, interleaved with `deflectable` focused shots every 5 s.
   - Total HP: 10.  Phase-entry thresholds: phase 2 at hp ≤ 7, phase 3 at hp ≤ 4.

---

## Implementation Notes

- `boss.gd` should `extends npc.gd` (or include it via composition) so all
  existing NPC behaviour (knockback, detection, `set_player_reference`, etc.)
  is inherited.
- The `phases` array is ordered: index 0 is the starting phase, index 1 is
  entered on first threshold, etc.
- Shoot patterns are implemented as new methods on the boss script, called from
  `_fire_projectile()` override.
- The deflection mechanic requires a small change to `projectile.gd`: add an
  `@export var deflectable: bool = false` and handle the melee-area overlap in
  `player.gd`.

---

## Dependencies

- Task 06 (level completion) for the boss-defeated → level-end flow.

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `scripts/boss.gd` | Create (extends npc.gd) |
| `scenes/boss_quirrell.tscn` | Create |
| `scripts/boss_quirrell.gd` | Create |
| `scripts/projectile.gd` | Add `deflectable` export + reflected state |
| `scripts/player.gd` | Deflect projectile in melee area overlap |
| `scripts/main.gd` | Connect `boss_defeated` to level completion |
