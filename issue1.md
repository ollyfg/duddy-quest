# Issue 1 — Split main.gd monolith into focused managers

## Problem

`scripts/main.gd` is 726 lines and handles room loading, room state
persistence, dialog orchestration, cinematic playback, HUD updates, level
progression, post-dialog side-effects, pathfinder rebuilding, and camera
management. Every new feature (quests, inventory screen, save/load, new
level intros) must be wired through this single file, creating merge
conflicts and cross-feature coupling.

## Suggested approach

Extract responsibilities into autoloads or child-node scripts:

| New script | Responsibility | Lines to move |
|---|---|---|
| `room_manager.gd` | `_load_room`, `_save/_restore_room_state`, `_on_exit_triggered`, room scene lifecycle | ~150 lines |
| `dialog_manager.gd` | `_on_npc_interaction_requested`, `_pick_npc_dialog`, `_on_dialog_ended`, `_handle_post_npc_dialog`, `_set_dialog_active` | ~130 lines |
| `hud_manager.gd` | `_init_hp_bar`, `_update_hp_display`, `_update_key_display`, `_update_rage_bar`, `_update_wand_display`, game-over overlay, flash effect | ~80 lines |
| `level_manager.gd` | `_load_level`, `_on_level_end_reached`, `_show_level_complete`, cutscene orchestration | ~80 lines |

After extraction, `main.gd` becomes a thin coordinator connecting the
managers via signals.

## Acceptance criteria

- [ ] Each manager can be tested in isolation with a minimal scene tree
- [ ] Existing GUT tests still pass (`tools/run_tests.sh`)
- [ ] `check_rooms.py` and `check_alignment.py` still pass
- [ ] No change to player-visible behaviour — verify with `playtest.py`
