# Task 12 — Level 2: *The Wrong Alley Entirely* (Diagon Alley)

## Summary
Build the second level, set in the Leaky Cauldron and Diagon Alley.  The level
ends with Dudley obtaining his wand from Ollivander and heading for King's Cross.
It introduces the wand and fires the first proper miniboss fight (Draco Malfoy).

---

## Prerequisites (must be merged first)

| Task | Feature needed |
|------|---------------|
| Task 01 | Cutscene panels for level intro/outro and Ollivander wand acquisition |
| Task 02 | Cinematic sequence for Lucius watching + wand-choice moment |
| Task 04 | Multi-option dialogue for Gringotts goblin debate |
| Task 06 | Level completion trigger (heading to King's Cross) |
| Task 08 | Pushable mannequins in Madam Malkin's |

---

## Level Structure

```
[Intro cutscene — Dudley barges into the Leaky Cauldron]
    │
    ▼
room_2a — The Leaky Cauldron
    │ east exit (through the brick wall)
    ▼
room_2b — Diagon Alley Entrance (Cornish Pixies blockade)
    │ east exit (after clearing pixies)
    ▼
room_2c — Diagon Alley Main (navigation / sign puzzle)
    │ north exit (Gringotts)
    │ south exit (Madam Malkin's)
    │ east exit (Ollivander's)
    ▼
room_2d — Gringotts Exchange Hall (goblin exchange-rate debate)
    │ south exit back to room_2c
    ▼
room_2e — Madam Malkin's (pushable mannequin puzzle)
    │ north exit back to room_2c
    ▼
room_2f — Ollivander's (wand acquisition cinematic)
    │ west exit (returns to room_2c)
    ▼
room_2c alley mouth (Draco miniboss arena)
    │ west exit (level end → King's Cross)
    ▼
[Outro cutscene → Level 2 Complete]
```

---

## Room Specifications

### room_2a — The Leaky Cauldron
- Tom the barkeep (friendly NPC, STATIONARY) at the bar with a one-line dialog.
- Brick wall on the east end: an interactable switch or trigger zone ("touch
  the wall") that transitions the player to room_2b.  No key required.
- Flavor dialog if the player talks to Tom:
  > "Can I help you?  …Oh.  You'd better head through the back."

### room_2b — Diagon Alley Entrance
- Three **Cornish Pixie** enemies (hostile, CHASE, small, fast) block the east
  path.  The player must defeat all three (they are in a `"room_clear"` group)
  before the east exit unlocks.
- Use a simple `RoomClearTrigger` that watches for all enemies in the group to
  be dead, then enables the east exit.

#### Room Clear Trigger (new small utility)
Create `scripts/room_clear_trigger.gd` (optional helper):
- `@export var enemy_group: String = "enemy"` — watches this group within the
  current room.
- `@export var unlocks_exit: String = "east"` — direction string of the exit to
  enable.
- Polls (or connects to `tree_exited` signals) until all enemies in the group
  within the room are gone, then enables the exit.

### room_2c — Diagon Alley Main (Navigation Puzzle)
- Wide, maze-like room with leaning facades, branching alleys, and hanging shop
  signs.
- **Sign puzzle:** Several sign posts with arrows; reading the signs in the
  correct order identifies the route to Ollivander's (east).  Going the wrong
  way brings the player back to the start of the alley (a loop-back exit).
- NPC: Neville Longbottom (friendly, WANDER) wandering anxiously.  His dialog:
  > "I keep getting turned around.  I think Ollivander's is east but the alley
  > keeps pointing me west…"
- After Draco miniboss is defeated (see below), the west exit leading out of
  Diagon Alley becomes active as the level-end trigger.

### room_2d — Gringotts Exchange Hall (Muggle Money Exchange Puzzle)

Dudley has no wizard money and no vault — he's Muggle-raised and was never set
one up.  He does, however, have a substantial wad of birthday cash (his parents
have always substituted money for attention).  Gringotts offers a Muggle Money
Exchange service; Dudley presents himself at the counter to use it.

The goblin exchange clerk makes the process as painful as possible: the exchange
rate board has been rotated to face the wall, the quoted rate is three Galleons
per pound when the (barely visible) board showed seventeen, and every question
is met with a different bureaucratic objection.  Dudley is not financially naive
— his father drummed one lesson into him: never accept the first number in a
transaction.

Uses the Task 04 branching dialogue system.

Dialog tree summary:
```
Goblin: "Exchange services are for established account holders only.  Move along."

→ Choice: [Dudley looks around the hall]
    A) "I'd like to open an account, then."
       → "New account applications take six to eight weeks."  [fail — loop back]
    B) "That rate board on the wall appears to be facing backwards."
       → Goblin stiffens.  "...The board is under maintenance."
       → Choice: [Dudley squints at the board]
           A) "I can still read it.  Seventeen Galleons per ten pounds."
              → Goblin very still.  "...Exchange minimum is fifty pounds."
              → Choice: [Dudley counts his birthday money]
                  A) "I have thirty-seven pounds."
                     → "Insufficient."  [fail — loop back]
                  B) "I have sixty pounds."
                     → Very long pause.  Goblin processes the transaction at
                        the posted rate.  "One hundred and two Galleons.
                        Do not ask about the mine carts."  [success → exits open]
           B) "It doesn't matter, I'll take your rate."
              → "...Very well.  That will be three Galleons."  [fail — loop back]
```
Success ends the conversation and enables the south exit back to the alley.
Dudley leaves Gringotts with Galleons to spend on robes and supplies.

### room_2e — Madam Malkin's (Mannequin Puzzle)
- Uses `pushable_block.tscn` (Task 08) for mannequins (`piece_type = "free"`).
- Three mannequins slowly rotate (visual-only; they are represented as
  pushable blocks that rotate their sprite on a timer without physically moving).
- The **discount ledger** is a KEY item (key_id = `"discount_ledger"`) that
  has fallen behind a display stand.
- The display stand is a `StaticBody2D`; the ledger is accessed by pushing a
  mannequin aside to create a path.
- Picking up the ledger drops the robe price (flavor dialog from Madam Malkin):
  > "Oh!  There's the discount book.  Very well — 40% off for finding it."
- Collecting the ledger enables the north exit back to room_2c.

### room_2f — Ollivander's (Wand Acquisition)
- Mr Ollivander (friendly NPC, STATIONARY) behind the counter.
- Dialog with Ollivander (linear, no choices):
  > Lines 1–3: standard wand-shop banter; a few wands are tried and "don't fit".
  > Line 4: *"Maple and unicorn tail-hair, eight and three-quarter inches…"*
- After dialog ends, a WAND item is spawned at the counter; player walks
  into it to pick it up, triggering `player.has_wand = true`.
- **Wand acquisition cinematic (Task 02):** a brief cinematic plays — a golden
  spark shoots from Ollivander's window and sets a sign outside on fire.
  Ollivander: *"…I expect great things."*
- After the cinematic, the west exit back to room_2c opens.

### room_2c (revisited) — Draco Miniboss Arena
- When the player re-enters room_2c **after** obtaining the wand, Draco Malfoy
  is present at the west end (the only path to the level exit).
- Draco is a hostile NPC with KEEP_DISTANCE mode: he fires jinxes (projectiles)
  at range and refuses close-quarters combat.
- **Pre-wand phase:** Dudley cannot fire back (has_wand is false for this one
  encounter?).  No — by this point Dudley has the wand.  Draco fires bursts of
  3 projectiles; player dodges and counter-fires with the wand.
- When Draco's HP reaches 0, a brief dialog (cinematic):
  > Lucius (off-screen voice): "Draco.  That's enough."  
  > Draco (fuming): exits east.
- The west exit (level-end trigger) unlocks.

---

## Intro Cutscene (Slides)

1. *"London. The bus deposits Dudley outside a pub called The Leaky Cauldron."*
2. *"He goes in looking for the loo."*
3. *"He comes out the back into something else entirely."*

---

## Outro Cutscene (Slides)

1. *"Wand in pocket, supplies procured (approximately)."*
2. *"Dudley Dursley heads for King's Cross."*
3. *"He has no idea which platform."*

---

## Adding to `main.gd`

```gdscript
"level_2": {
    "start_room": "room_2a",
    "start_pos": Vector2(64.0, 240.0),
    "next_level": "level_3",
    "rooms": { ... },
    "connections": { ... },
},
```

Rooms stored in `scenes/level2/`.

---

## Art Notes (Placeholder)

- Leaky Cauldron: dark brick walls, wooden floor.
- Diagon Alley: cobblestone floor, colourful shopfront facades.
- Gringotts: marble floor, tall columns.
- Madam Malkin's: cream walls, coloured mannequins.
- Ollivander's: dusty, stacked boxes (dark rectangles), narrow.
- Draco NPC: white/blonde ColorRect, faster move speed.
- Cornish Pixies: bright blue, tiny.

---

## Files to Create

| File | Notes |
|------|-------|
| `scenes/level2/room_2a.tscn` through `room_2f.tscn` | Six rooms |
| `scripts/room_clear_trigger.gd` | New utility (enemy group → unlock exit) |
| `scripts/main.gd` | Add `level_2` entry |
