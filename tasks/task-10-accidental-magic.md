# Task 10 — Accidental Magic / Frustration Mechanic

## Summary
Implement a "frustration meter" that fills when the player repeatedly mashes
action buttons without effect, and discharges as an involuntary burst of
accidental magic when full.  This is the mechanic used in Level 1 to rattle
the locked door off its hinges.

---

## Motivation (from the plot — Level 1)

> **The Locked Door:** Use accidental magic (triggered by mashing the attack
> buttons in frustration) to rattle the handle until the lock gives way — but
> only *after* working out that magic won't fire unless Dudley is genuinely
> furious.  Clue: re-reading the letter out loud does the trick.

The intended flow:
1. Player finds the locked door and tries to open it — nothing happens.
2. Player discovers the Hogwarts letter in the room (reading it triggers a
   dialog).
3. After reading the letter a flag is set: Dudley is now "furious".
4. Player mashes the attack buttons several times in frustration.
5. The frustration meter fills; accidental magic fires, blasting the door open.

---

## Acceptance Criteria

### Frustration Meter

1. `player.gd` gains:
   ```gdscript
   var frustration: float = 0.0          # 0.0 – 1.0
   var frustration_enabled: bool = false # must be true for meter to fill
   signal frustration_full               # emitted when frustration reaches 1.0
   signal frustration_changed(value: float)
   ```

2. While `frustration_enabled` is `true`, each press of `melee_attack` or
   `ranged_attack` that does **not** hit any enemy or target adds
   `FRUSTRATION_PER_MISS: float = 0.25` to `frustration` (clamped to 1.0).
   Frustration decays slowly when no button is pressed:
   `frustration -= FRUSTRATION_DECAY_RATE * delta` (decay rate ≈ 0.05 /s).

3. When `frustration >= 1.0`, `frustration_full` is emitted, `frustration` is
   reset to 0.0, and an accidental-magic visual burst plays (see below).

4. A small frustration bar is shown in the HUD while `frustration_enabled` is
   true (next to the HP dots).  The bar is hidden otherwise.

### Detecting a "Miss"

5. The existing melee system in `player.gd` uses an `Area2D` (`MeleeArea`) that
   monitors for bodies.  Track whether any body entered during the current
   swing; if the swing timer expires and no body was hit, increment frustration.

6. Similarly for ranged attacks: if the projectile despawns without hitting an
   enemy, this counts as a miss.  This is tracked via a `projectile_missed`
   signal on `projectile.gd` emitted when the projectile's lifetime runs out
   without a hit.

### Accidental Magic Effect

7. When `frustration_full` fires, play a visual burst:
   - A brief screen flash (white semi-transparent `ColorRect` overlay that
     fades in 0.1 s then fades out 0.3 s).
   - The player sprite flashes bright white for 0.2 s.
   - An `AccidentalMagicArea2D` child on the player briefly activates (radius
     ≈ 48 px) — any node in the `"breakable"` or `"accidental_magic_target"`
     group within range has its `on_accidental_magic()` method called.

### Locked Door Integration

8. A new scene `scenes/magic_door.tscn` with script `scripts/magic_door.gd`:
   - A `StaticBody2D` obstacle (blocks passage until opened).
   - In the `"accidental_magic_target"` group.
   - `func on_accidental_magic() -> void` — plays an opening animation
     (door slides aside), disables collision, emits `signal door_opened`.
   - `@export var requires_frustration_enabled: bool = true` — if true, only
     responds to accidental magic while the player's `frustration_enabled` is
     true.

### Letter Item (Trigger for Frustration Mode)

9. A new item type or interactable `@export` on a standard NPC or item node
   that, when "read" (player presses interact while adjacent), calls
   `player.frustration_enabled = true` and starts a short dialog:
   > "D. DURSLEY (THE LARGER ONE) — You are hereby invited to attend
   > Hogwarts School of Witchcraft and Wizardry…"

   This can be implemented as a friendly NPC with a special post-dialog
   callback, or as a distinct `ReadableItem` scene.

---

## Implementation Notes

- The frustration system is opt-in (`frustration_enabled = false` by default)
  so it does not affect any existing levels.
- The accidental magic burst should feel spectacular but brief — players
  should understand immediately that something unusual happened.
- The miss-detection for melee: set a `_melee_hit_this_swing: bool` flag,
  reset to `false` at swing start, set to `true` in `_on_melee_area_body_entered`
  if the body is an enemy.  At swing end (the `await` timer completes) check
  the flag.

---

## Dependencies

- Task 06 (level completion) is not a dependency, but Level 1's locked-door
  puzzle wires this mechanic into a door that, once opened, progresses the
  level.

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `scripts/player.gd` | Add frustration meter logic, accidental magic area |
| `scripts/projectile.gd` | Add `projectile_missed` signal |
| `scenes/magic_door.tscn` | Create |
| `scripts/magic_door.gd` | Create |
| `scenes/main.tscn` | Add frustration-bar UI element to HUD |
| `scripts/main.gd` | Show/hide frustration bar based on `frustration_enabled` |
