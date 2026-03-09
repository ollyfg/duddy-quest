# Level 2 Task 1 — Level 2 infrastructure and room scaffolding

## Context

Level 2 takes place in **Diagon Alley**. The player enters via the Leaky
Cauldron and must navigate shops, solve puzzles, and defeat Draco Malfoy
before leaving with a wand. This card sets up the structural skeleton
that all other Level 2 cards build on.

## Rooms to create

| Room name | Scene file | Description |
|---|---|---|
| `l2_leaky_cauldron` | `scenes/l2_leaky_cauldron.tscn` | Pub interior — entry point, Tom the barkeep |
| `l2_diagon_alley_south` | `scenes/l2_diagon_alley_south.tscn` | Southern street section, connects to Leaky Cauldron and Gringotts |
| `l2_diagon_alley_north` | `scenes/l2_diagon_alley_north.tscn` | Northern street section, connects to shops and Ollivander's |
| `l2_gringotts` | `scenes/l2_gringotts.tscn` | Bank interior — money exchange puzzle |
| `l2_madam_malkins` | `scenes/l2_madam_malkins.tscn` | Robe shop — mannequin puzzle |
| `l2_ollivanders` | `scenes/l2_ollivanders.tscn` | Wand shop — wand acquisition |
| `l2_menagerie` | `scenes/l2_menagerie.tscn` | Pet shop — pixie escape source |
| `l2_alley_end` | `scenes/l2_alley_end.tscn` | Final street section — Draco miniboss arena, level exit |

## Tasks

1. Add `"level_2"` entry to the `LEVELS` dictionary in `main.gd` (or the
   data file if Issue 5 is done) with all rooms, connections, start room
   (`l2_leaky_cauldron`), start position, and `next_level: ""`.
2. Create empty room `.tscn` files extending `room.gd` with:
   - Correct `room_size`
   - Exit `Area2D` nodes matching the connection directions
   - Basic floor/wall `TileMap` or `ColorRect` placeholder
3. Update `level_select.gd` `LEVEL_LIST` if needed (already has a
   `level_2` entry).
4. Run `check_rooms.py` and `check_alignment.py` to validate connections
   and grid alignment.
5. Launch the game, select Level 2, and walk between all rooms using
   `playtest.py` to confirm transitions work.

## Acceptance criteria

- [ ] All 8 room scenes exist and load without errors
- [ ] Room connections are symmetric (east↔west, north↔south)
- [ ] `check_rooms.py` passes with Level 2 included
- [ ] Player can walk from Leaky Cauldron through all rooms to the level
      end trigger
- [ ] Level 2 appears and is selectable in the level select screen
