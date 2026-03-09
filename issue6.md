# Issue 6 — Add schema validation for boss phases, cinematic steps, and dialog data

## Problem

Three major systems pass untyped `Dictionary` / `Array` data through the
engine at runtime:

| System | Data shape | Risk |
|---|---|---|
| Boss phases (`boss.gd`) | `{"hp_threshold": int, "movement_mode": enum, ...}` | Missing key → null crash |
| Cinematic steps (`cinematic_player.gd`) | `{"type": "move_npc", "npc": "Name", "to": Vector2}` | Typo in `"type"` → silently skipped |
| Dialog lines (`dialog_box.gd`) | `String` or `{"text": str, "options": [...]}` | Malformed dict → invisible dialog |

All three rely on `dict.get("key", default)` which silently swallows
errors. A misspelled key like `"hp_threshhold"` or `"diaglog"` is never
caught until a player hits the broken path.

## Suggested approach

For each data structure, add a lightweight validation function that runs
in `#debug` builds (or always, if cheap):

```gdscript
# boss.gd
static func _validate_phase(phase: Dictionary) -> void:
    assert(phase.has("hp_threshold"), "Phase missing hp_threshold")
    assert(phase.has("movement_mode"), "Phase missing movement_mode")
    # ...
```

Call validators in `_ready()` or when data is first assigned. Use
`push_error()` for non-fatal issues and `assert()` for must-fix issues
so playtesters see clear messages.

For cinematic steps, validate that:
- `"type"` is in a known set of step types
- Required keys per type are present (e.g. `"move_npc"` needs `"npc"`
  and `"to"`)
- Referenced node paths exist in the current room

## Acceptance criteria

- [ ] A misspelled boss phase key triggers a visible error in debug builds
- [ ] An unknown cinematic step type logs a clear warning
- [ ] Dialog data with missing `"text"` key shows an error, not blank text
- [ ] Validation does not run in release builds (use `OS.is_debug_build()`)
- [ ] Existing data passes validation without changes
