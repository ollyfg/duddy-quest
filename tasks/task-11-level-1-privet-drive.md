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
| Task 04 | Multi-option dialogue for Mrs. Figg's cat puzzle |
| Task 05 | KEY item for bus fare |
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
room_1d — Back Garden        (Ripper patrol, garden gate)
    │ south exit (gate, requires "bus_fare" key)
    ▼
room_1e — Magnolia Crescent  (Piers gang combat + Mrs. Figg cat puzzle)
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
- Mrs. Figg is positioned at the gate.  Approaching her triggers the cat
  identification multi-option dialog puzzle (see below).

#### Mrs. Figg's Cat Puzzle
Uses the Task 04 branching dialogue system.

Dialog tree summary:
```
Figg: "Oh, Dudley dear!  Have you seen Mr Tibbles?  
       He's a tabby, notched left ear, blue collar — 
       not like Snowy (white, no collar) or Mr Whiskers (ginger, red collar)."

→ Choice: "Which cat is Mr Tibbles?"
    A) The ginger one by the roses
       → "That's Snowy, dear.  No, no."  [wrong — loop back]
    B) The white fluffy one
       → "Oh heavens no, that's Mr Whiskers!"  [wrong — loop back]
    C) The tabby with the blue collar
       → "Yes!  Oh thank you Dudley.  He had your bus fare under his collar —
          goodness knows how he got it."  [correct → drops bus_fare key item]
```
Choosing a wrong option loops back to the choice rather than ending the dialog.
Choosing correctly drops a KEY item (key_id = `"bus_fare"`) at Mrs. Figg's feet
and closes the gate-blocking conversation.

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
