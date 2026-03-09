# Issue 4 — Introduce an NPC state machine to replace ad-hoc mode logic

## Problem

`scripts/npc.gd` handles six `MovementMode` values (CHASE, KEEP_DISTANCE,
WANDER, PATROL, STATIC, DEFAULT) inside a single `_physics_process()`
that is already ~75 lines long with deeply nested match arms. Behaviours
like "chase until player is far, then return to patrol" are encoded as
scattered `if` chains rather than explicit state transitions.

Every new behaviour (flee, stunned, frozen, alerted, sleeping) will need
more branches in the same function. The file is already 486 lines with
30+ `@export` properties — the largest non-main script.

## Suggested approach

Implement a lightweight state-machine pattern **without** adding an
external library:

```gdscript
# In npc.gd or a new npc_state_machine.gd

enum State { IDLE, WANDER, PATROL, CHASE, KEEP_DISTANCE, STUNNED, FLEE }

var _state: State = State.IDLE

func _physics_process(delta: float) -> void:
    match _state:
        State.IDLE:     _process_idle(delta)
        State.WANDER:   _process_wander(delta)
        State.CHASE:    _process_chase(delta)
        # ...

func transition_to(new_state: State) -> void:
    _exit_state(_state)
    _state = new_state
    _enter_state(_state)
```

Each state handler is a small, testable method. State transitions are
explicit and loggable. Future states (STUNNED, FLEE, ALERTED) slot in
without touching existing logic.

Consider also splitting the 30+ exports into behaviour-group sub-resources
(e.g. `PatrolConfig`, `CombatConfig`, `DialogConfig`) so the inspector
doesn't overwhelm designers.

## Acceptance criteria

- [ ] `_physics_process` delegates to per-state handlers; no nested match
- [ ] State transitions logged in debug builds
- [ ] Hostile and friendly NPC tests still pass
- [ ] Petunia patrol/chase/kick-back behaviour unchanged — verify with
      `playtest.py` in the hallway room
