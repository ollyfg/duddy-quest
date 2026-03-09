# Issue 8 — Centralise dialog branching into a dialog manager

## Problem

NPC dialog selection logic lives in `main.gd::_pick_npc_dialog()` (lines
374–402) and uses a priority chain of `if` checks:

1. Does NPC require a key the player has? → `key_accept_dialog`
2. Does NPC have `after_key_id` matching a player key? → `after_key_dialog`
3. Does NPC have a flag gate the player hasn't met? → `pre_flag_dialog`
4. Does NPC have random `dialog_pools`? → pick random pool
5. Fallback → `dialog_lines` + `dialog_suffix`

Post-dialog effects (`_handle_post_npc_dialog`) also live in `main.gd`:
consuming keys, giving keys, setting flags, freeing NPCs.

Every new gate type (quest completion, item in inventory, time-of-day,
relationship level) requires adding another `if` branch in the central
game controller.

## Suggested approach

Create `scripts/dialog_manager.gd` that owns dialog selection and
post-dialog side-effects. The manager receives the NPC's exported
properties and the player's current state, and returns the dialog lines
plus a list of deferred effects:

```gdscript
class_name DialogManager

func pick_dialog(npc_data: Dictionary, player_state: Dictionary) -> Dictionary:
    # Returns {"lines": [...], "effects": [...]}

func apply_effects(effects: Array, player: Node, npc: Node) -> void:
    for e in effects:
        match e["type"]:
            "consume_key": player.remove_key(e["key_id"])
            "give_key":    player.add_key(e["key_id"])
            "set_flag":    GameState.set_flag(e["flag"])
            "remove_npc":  npc.queue_free()
```

New gate types are added as entries in `pick_dialog` without touching
`main.gd`.

## Acceptance criteria

- [ ] `main.gd` no longer contains `_pick_npc_dialog` or
      `_handle_post_npc_dialog`
- [ ] Dialog manager is unit-testable with mock NPC/player data
- [ ] All existing NPC conversations work identically
- [ ] At least one new gate type (e.g. `requires_item`) can be added by
      editing only the dialog manager
