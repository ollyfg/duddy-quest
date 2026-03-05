# Task 11 — Level 1: *A Perfectly Normal Catastrophe* (Privet Drive)

## Summary
Build the complete first level of Dudley Quest, set in and around 4 Privet Drive
and Magnolia Crescent.  The level introduces the game world, teaches basic
movement and combat, and ends with Dudley boarding the wrong bus to London.

---

## Prerequisites (must be merged first)

| Task | Feature needed |
|------|---------------|
| Task 01 | Cutscene panels for level intro and outro |
| Task 03 | PATROL movement for Aunt Petunia and Ripper |
| Task 05 | KEY item for bus fare (dropped by Mr Tibbles) |
| Task 06 | Level completion trigger (boarding the bus) |
| Task 10 | Accidental magic for the locked-door puzzle |

---

## Level Structure

```
[Intro cutscene]
    │
    ▼
room_1a — Dudley's Bedroom   (locked door puzzle, letter item)
    │ south exit (after door opens)
    ▼
room_1b — Upstairs Landing   (Petunia patrol gauntlet)
    │ south exit (after gauntlet)
    ▼
room_1c — Downstairs Hallway (friendly NPC: Uncle Vernon blocks path)
    │ west exit
    ▼
room_1d — Back Garden        (Ripper patrol, cats on lawn, Mrs. Figg at gate)
    │ south exit (gate, requires "bus_fare" key)
    ▼
room_1e — Magnolia Crescent  (Piers gang combat)
    │ east exit (bus stop, level end trigger)
    ▼
[Outro cutscene → Level 1 Complete]
```

---

## Room Specifications

### room_1a — Dudley's Bedroom
- Player starts at north end of the room.
- **Letter item** (readable interactable) sits on the desk; reading it sets
  `player.frustration_enabled = true` and shows a dialog of the letter text.
- **Magic door** (`magic_door.tscn`) blocks the south exit.
- After frustration-full fires, the magic door opens, leading south.
- Room contains a health item (pudding on the table) as a tutorial pickup.

### room_1b — Upstairs Landing
- A horizontal corridor with Aunt Petunia (PATROL NPC, non-hostile).
- Petunia walks between two `PatrolPoint` nodes at the east and west ends, with
  a 1-second pause at each end.
- She has a wide collision body; if she touches the player the player is pushed
  back (bumped, not damaged) and a line of dialog fires:
  > "Dudley! Back to your room this instant!"
  Petunia continues her patrol after the dialog.
- The exit is on the south side; the player must dash through during the gap in
  her route.  The gap is approximately 2 seconds wide.

### room_1c — Downstairs Hallway
- Uncle Vernon sits in an armchair blocking the west exit.
- He has a short linear dialog sequence explaining he doesn't want Dudley
  "going out and getting ideas".  After the dialog he falls asleep (STATIONARY)
  and the player can sneak past west.

### room_1d — Back Garden
- Ripper (hostile bulldog NPC, PATROL mode) patrols east–west across the
  centre of the garden.
- The garden gate at the south is a locked exit requiring key id `"bus_fare"`.
- **Three cat NPCs** (WANDER mode, non-hostile) stroll around the garden lawn:
  - **Snowy** — white NPC sprite, no collar.
  - **Mr Whiskers** — ginger/orange NPC sprite, red collar.
  - **Mr Tibbles** — tabby (grey-striped) NPC sprite, blue collar.  This is the
    correct cat.
- **Mrs. Figg** stands STATIONARY directly in front of the garden gate, blocking
  it.  She will not move until Mr Tibbles is brought back to her.
- Approaching Mrs. Figg triggers her opening dialog (linear, no choices):
  > *"Oh, Dudley dear!  I can't let you through — I've lost Mr Tibbles and I'm
  >  not moving until someone finds him.  He's a tabby, proper tabby, with a
  >  notch in his left ear and a blue collar.  Not like Snowy, who's all white,
  >  or Mr Whiskers who's ginger with a red collar.  Have a look around the
  >  garden, dear."*
- The player must explore the garden and interact with each cat:
  - Interacting with **Snowy**: brief dialog — *"Mrrrow."* (Snowy stares at you
    without interest.  This is not Mr Tibbles.)
  - Interacting with **Mr Whiskers**: brief dialog — *"Mrrp."* (This cat is
    ginger with a red collar.  Definitely not Mr Tibbles.)
  - Interacting with **Mr Tibbles** (tabby, blue collar): brief dialog — *"Prrr."*
    (This cat has a blue collar with a notch in his left ear.  A small KEY item
    (`key_id = "bus_fare"`) drops from under his collar.)
- Once the player has the `"bus_fare"` key, Mrs. Figg's dialog changes:
  > *"Oh, there he is!  You found him, Dudley dear — and look, he had your bus
  >  fare under his collar.  Goodness knows how he got it."*
  She steps aside, and the south gate exit becomes usable with the key.

#### Implementation Notes
- The cat NPCs use `npc.gd` with `movement_mode = WANDER`, `is_hostile = false`,
  `hp = 1` (indestructible for gameplay — use a large `MAX_HP` or disable damage).
- Mr Tibbles has a custom `interaction_requested` handler in `room_1d.tscn` that
  spawns the `"bus_fare"` KEY item at his position when interacted with.
- Mrs. Figg uses `movement_mode = STATIONARY` and is placed directly on the gate
  tile so she physically blocks the south exit area.  Her dialog cycling (before
  / after Tibbles found) can be driven by checking whether the player carries the
  `"bus_fare"` key (`player.key_count` or a room-local flag).

### room_1e — Magnolia Crescent
- Wide room with three **Piers Polkiss gang members** (hostile CHASE NPCs).
- The gang members are spread across the room; the player must defeat all three
  to clear the path to the bus stop.
- **Bus stop** is a `level_end_trigger.tscn` at the east end of the room.
- Level-end cutscene slides (placeholder art for now): "Dudley boards Bus 43...
  but this is not the right bus..."

---

## Intro Cutscene

Slides (plain text, placeholder art):
1. *"4 Privet Drive, Little Whinging, Surrey.  The morning after."*
2. *"Harry's Hogwarts letter caused the usual uproar.  Nobody noticed the second
   envelope sliding under the toaster."*
3. *"But Dudley noticed."*

---

## Outro Cutscene

Slides:
1. *"Magnolia Crescent, Bus Stop 14.  A bus arrives."*
2. *"It is not the Number 7 to Little Whinging."*
3. *"It is, in fact, the Number 666 to Central London — last stop: The Leaky Cauldron."*
4. *"Dudley gets on anyway."*

---

## Adding the Level to `main.gd`

Add to the `LEVELS` dictionary:

```gdscript
"level_1": {
    "start_room": "room_1a",
    "start_pos": Vector2(320.0, 80.0),
    "next_level": "level_2",
    "rooms": {
        "room_1a": preload("res://scenes/level1/room_1a.tscn"),
        ...
    },
    "connections": { ... },
},
```

Rooms for Level 1 should be stored in `scenes/level1/`.

---

## Art Notes (Placeholder)

All visuals can use solid `ColorRect` shapes until real pixel art is created:
- Dudley's bedroom: brown floor, beige walls, desk (dark rectangle).
- Landing: grey floor, striped wallpaper.
- Garden: green floor, fence sprites.
- Crescent: dark grey pavement, building facades as wall tiles.
- Aunt Petunia NPC: pink/lilac ColorRect.
- Ripper: brown ColorRect, faster move speed than standard NPC.
- Piers gang: orange ColorRects.

---

## Files to Create

| File | Notes |
|------|-------|
| `scenes/level1/room_1a.tscn` | Bedroom |
| `scenes/level1/room_1b.tscn` | Landing (Petunia patrol) |
| `scenes/level1/room_1c.tscn` | Hallway (Vernon) |
| `scenes/level1/room_1d.tscn` | Garden (Ripper, Mrs. Figg puzzle) |
| `scenes/level1/room_1e.tscn` | Magnolia Crescent (gang fight, level end) |
| `scripts/main.gd` | Add `level_1` to LEVELS |
