# Level 2 Task 6 — Cornish Pixie enemies and Magical Menagerie

## Context

Cornish Pixies have escaped from the Magical Menagerie and block routes
through Diagon Alley. They are the primary combat encounter for Level 2
before the player acquires the wand. After wand acquisition, a second
wave appears for the player's first ranged-combat practice.

## Requirements

### Cornish Pixie enemy type

Create a new enemy variant using the existing `npc.tscn` / `npc.gd`
hostile NPC system:

| Property | Value |
|---|---|
| `is_hostile` | `true` |
| `movement_mode` | `CHASE` (or new `SWARM` if added) |
| `move_speed` | `120.0` (faster than standard enemies) |
| `hp` | `1` (fragile — one melee or ranged hit kills) |
| `contact_damage` | `1` |
| Color | Purple/blue (`Color(0.4, 0.3, 0.8)`) |
| Size | Smaller than standard NPCs (scale `0.6`) |

**Swarming behaviour**: Pixies should appear in groups of 3–5. They chase
the player but with slight random offset to avoid stacking on the same
pixel. Consider adding a small random wander component to the chase
vector.

If the existing NPC movement modes don't support swarming well, add a
`SWARM` movement mode or use `CHASE` with a random offset export.

### Magical Menagerie room (`l2_menagerie.tscn`)
- Connected from `l2_diagon_alley_south` (or north — coordinate with
  Task 3 for final connection map)
- Pet shop interior: cages, animal crates, an open/broken cage as the
  pixie source
- 3–4 pixies inside the room
- Optional: a friendly shopkeeper NPC apologising for the escape

### Pixie encounters in street rooms
- `l2_diagon_alley_south`: 2–3 pixies blocking the path east to Gringotts
  on first visit. They respawn if the room is re-entered before a
  certain flag.
- `l2_alley_end`: 4–5 pixies appear **after** the wand is acquired
  (flag `l2_has_wand`). This is the ranged-combat tutorial encounter.

### Post-wand pixie wave (in `l2_alley_end`)
- Triggered by flag `l2_has_wand` on room entry
- Brief cinematic: pixies swarm in from off-screen, attracted by the
  golden wand spark
- Player must defeat all pixies to proceed to the Draco encounter
- Dialog from a nearby NPC: "Use your wand! Press V to fire!"

## Acceptance criteria

- [ ] Pixies chase the player and deal contact damage
- [ ] Pixies die in one hit (melee or ranged)
- [ ] Groups of pixies don't stack on the exact same position
- [ ] Pre-wand pixies appear in the street, defeatable with melee
- [ ] Post-wand pixies appear in `l2_alley_end`, teaching ranged combat
- [ ] Menagerie room has broken cage as narrative source
- [ ] All rooms pass `check_alignment.py`
