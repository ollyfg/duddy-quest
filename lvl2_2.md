# Level 2 Task 2 — Leaky Cauldron room and Tom the barkeep

## Context

The Leaky Cauldron is the entry room for Level 2. Dudley stumbles in
looking for a toilet and accidentally walks through the brick wall into
Diagon Alley. Tom the barkeep is a friendly NPC who gives exposition.

## Requirements

### Room layout (`l2_leaky_cauldron.tscn`)
- Dark pub interior with tables and chairs (obstacle `StaticBody2D` nodes)
- Entry position on the west side (player spawns here)
- East exit leads to `l2_diagon_alley_south` (the brick wall passage)
- Atmospheric: dim, cluttered, a few patron silhouettes as decoration

### Tom NPC
- Friendly NPC (blue, `is_hostile = false`) placed behind the bar counter
- `npc_name`: `"Tom"`
- Dialog lines introducing Diagon Alley:
  1. "Welcome to the Leaky Cauldron, lad!"
  2. "Through that wall is Diagon Alley. Best place for school supplies."
  3. "You'll want Gringotts for your money, then the shops."
- No key gates, no flag requirements — purely expository

### Intro cinematic
- On first visit, play a brief cinematic:
  1. Pan camera to show the pub interior
  2. Tom walks over to Dudley
  3. Dialog plays
  4. Camera resets, player gains control
- Set flag `l2_leaky_cauldron_intro_shown` to prevent replay

## Acceptance criteria

- [ ] Room loads correctly from level select → Level 2
- [ ] Tom NPC triggers dialog on contact
- [ ] Intro cinematic plays on first visit only
- [ ] East exit transitions to `l2_diagon_alley_south`
- [ ] `check_alignment.py` passes (all nodes on 16px grid)
