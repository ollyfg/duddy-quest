# Issue 5 — Make level / room data declarative and data-driven

## Problem

The `LEVELS` dictionary in `scripts/main.gd` (lines 6–51) hard-codes
every room's `PackedScene` preload, directional connections, and entry
positions in GDScript source. This means:

1. **Adding a room** requires editing GDScript (not designer-friendly).
2. **Preloading** all room scenes at startup wastes memory. Level 2 adds
   8+ rooms; by Level 4 the preload list will be 30+ scenes.
3. **Validation tools** (`check_rooms.py`) must parse GDScript to extract
   the dictionary, which is fragile.

## Suggested approach

Move each level's metadata to a JSON (or Godot `.tres` Resource) file:

```
data/
  level_1.json
  level_2.json
```

```json
{
  "title": "A Perfectly Normal Catastrophe",
  "next_level": "level_2",
  "start_room": "l1_bedroom",
  "start_pos": [80, 240],
  "rooms": {
    "l1_bedroom": "res://scenes/l1_bedroom.tscn",
    "l1_upper_hall": "res://scenes/l1_upper_hall.tscn"
  },
  "connections": {
    "l1_bedroom": {
      "east": { "room": "l1_upper_hall", "entry": [64, 160] }
    }
  }
}
```

`main.gd` loads the JSON at level start and uses `load()` (not
`preload()`) for rooms, loading only the current room's scene on demand.

## Benefits

- Designers edit JSON, not GDScript
- `check_rooms.py` can validate JSON directly
- Memory footprint stays constant regardless of total room count
- Easier to auto-generate room graphs for debugging

## Acceptance criteria

- [ ] `LEVELS` dictionary is removed from `main.gd`
- [ ] Level metadata loaded from `data/*.json` at runtime
- [ ] `check_rooms.py` updated to read JSON instead of parsing GDScript
- [ ] `load()` used instead of `preload()` for room scenes
- [ ] All existing rooms and connections work identically
