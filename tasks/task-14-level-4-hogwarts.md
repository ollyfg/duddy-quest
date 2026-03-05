# Task 14 — Level 4: *Through the Back Door* (Hogwarts Castle)

## Summary
Build the final level, set in Hogwarts' underground trial chambers and the castle
above.  The level contains the game's most complex puzzles and culminates in a
three-phase boss fight against Professor Quirrell (with Voldemort on the back of
his head).

---

## Prerequisites (must be merged first)

| Task | Feature needed |
|------|---------------|
| Task 01 | Cutscene panels for level intro, each chamber, and the epilogue |
| Task 02 | Cinematic: Dumbledore's arrival + Sorting Hat epilogue |
| Task 06 | Level completion (boss defeat → level end) |
| Task 07 | Multi-phase boss fight (Quirrell / Voldemort) |
| Task 08 | Pushable chess pieces (chess puzzle room) |
| Task 09 | Light sources + Devil's Snare (vine room) |

---

## Level Structure

```
[Intro cutscene — Tradesmen's Entrance]
    │
    ▼
room_4a — Entrance Passage  (poltergeist debris combat)
    │ north exit
    ▼
room_4b — Devil's Snare Chamber  (light-source + vine puzzle)
    │ north exit (after vine cleared)
    ▼
room_4c — Flying Keys Chamber  (combat: hunt the bent-wing iron key)
    │ north exit (after key picked up and used on door)
    ▼
room_4d — Chess Chamber  (pushable chess pieces; two-move checkmate puzzle)
    │ north exit (after checkmate achieved)
    ▼
room_4e — Potions Chamber  (logic-riddle UI; select the correct bottle)
    │ north exit (after correct bottle chosen)
    ▼
room_4f — Upper Corridor  (Peeves ambushes; roaming debris; Filch patrol)
    │ north exit (stairwell)
    ▼
room_4g — Third-Floor Corridor  (Quirrell boss arena; Fluffy unconscious)
    │ [boss fight]
    ▼
[Boss defeat cinematic: Dumbledore arrives]
[Epilogue cutscene: Sorting Hat → HUFFLEPUFF]
[Level 4 Complete → Credits / Level Select]
```

---

## Room Specifications

### room_4a — Entrance Passage (Poltergeist Debris Combat)

- Three **Poltergeist Debris** enemies:
  - Floating hostile NPCs (CHASE, no contact damage — instead they fire
    enchanted objects as projectiles: chairs, ink pots).
  - Low HP (2 each), fast.
- Mrs Norris (non-hostile NPC, PATROL) patrols east–west.  If the player
  touches her, Mr Filch (hostile, faster, higher HP) enters from the east as
  a random encounter and must be defeated or outrun to the north exit.
- Nearly Headless Nick (friendly NPC, WANDER) gives the player a hint about
  what lies ahead:
  > *"Somebody came through here recently in quite a hurry.  I'd watch out for
  >  the plant in the next chamber.  It doesn't like company."*
- North exit is always open.

### room_4b — Devil's Snare Chamber (Light-Source Puzzle)

Uses the `LightSource` / `DevilsSnare` / `Torch` system (Task 09).

**Layout:**
- The room is filled with Devil's Snare vine (`devils_snare.tscn`).
- Four torch braziers (`torch.tscn`) are placed at fixed positions; each
  illuminates a radius of ~80 px.
- The north door is locked (`locked_door.tscn`, `required_key = ""`
  — it opens automatically when the path through the vine is clear, not via a
  key; use a trigger zone instead).

**Puzzle logic:**
- Braziers 1 and 2 must be lit to open a corridor through the south half.
- Brazier 3 must be lit to open a corridor through the north half.
- Each brazier stays lit for 8 seconds then gutters out (Task 09 `duration`).
- The player must: light brazier 1 → sprint north through the first gap → light
  brazier 3 → sprint to the door → the door area checks that brazier 3 is still
  lit and opens.
- Brazier 2 is a decoy (it illuminates a dead end).  The puzzle can be solved
  without it.
- Lighting a brazier: wand-blast (`ranged_attack`) the torch while facing it.

**Implementation:** The door area uses a `Area2D` that checks
`LightSource.is_point_lit(global_position, ...)` on the north path; when true,
the door opens.

### room_4c — Flying Keys Chamber (Key-Hunt Combat)

- Several dozen **Key NPC** enemies (flying, WANDER mode at high speed).
- One of them — the **correct key** (iron, bent wing, slightly larger sprite) —
  is in the `"correct_key"` group and has distinct coloring (dark grey).
- The correct key moves faster than the others (move_speed 120 vs 60) and has
  evasion logic: when the player is within 100 px it flees (KEEP_DISTANCE mode).
- Other keys periodically dive at the player (random direction projectile from
  the key's position, 1 damage).
- To progress: hit the correct key 3 times with wand-blasts (its HP = 3).
  When its HP reaches 0 it falls to the floor and becomes a KEY item
  (key_id = `"iron_key"`, spawned at the key's position).
- The north door is a `locked_door.tscn` with `required_key = "iron_key"`.

**Implementation:** The correct key is an NPC with special `_ready()` logic
that switches it to KEEP_DISTANCE when the player is near.

### room_4d — Chess Chamber (Pushable Chess Piece Puzzle)

Uses `pushable_block.tscn` (Task 08).

**Setup:**
- An 8 × 8 chess grid is drawn on the floor (visual TileMap or `GridOverlay`).
- Two white pieces remain:
  - **White Rook** (`piece_type = "rook"`) at grid position (0, 5).
  - **White Bishop** (`piece_type = "bishop"`) at grid position (4, 4).
- The **Black King** is a `StaticBody2D` (immovable) at grid position (4, 0).
- A `push_puzzle_trigger.tscn` checks:
  - White Rook at (0, 0) OR (4, 0) along same rank/file as the king.
  - White Bishop covers (4, 0) diagonally.
- When the trigger fires (`puzzle_solved`): a brief dialog from the pieces
  ("The white rook grumbles and complies"), and the north door opens.

**Intended solution:**
  1. Push the Rook to (0, 0) — threatens the king along the rank.
  2. Push the Bishop to a square where it covers (4, 0) — the king is in
     checkmate.

The pieces protest when given invalid moves (player is stopped; a small
dialogue bubble: *"Illegal move!"*) — implement via the piece_type restriction
in `pushable_block.gd`.

### room_4e — Potions Chamber (Logic Riddle Puzzle)

**Puzzle:** A row of seven bottles.  A logic riddle scroll.  Choose correctly.

**UI:** A dedicated puzzle overlay (CanvasLayer, similar to the Mandrake puzzle):
- Shows the scroll text (logic riddle extracted verbatim from PLOT.md lore;
  can be freely invented to match the flavor).
- Seven labeled bottle buttons (I through VII).
- Player selects a bottle; a brief pause then either:
  - Correct: the bottle glows and the north door opens.
  - Wrong (the cabbage-smelling one): the player takes 1 damage; a humorous
    dialog fires; the player may try again.
  - Wrong (other): player takes 1 damage; the dialog gives a subtle hint.
  - One wrong bottle is instant-death (poison) — the player is returned to the
    start of the room with full HP (treated as a room-restart, not game-over).

**Riddle (example — can be replaced with better copy):**
```
"Danger lies before you, safety lies behind.
 Three will ease the road ahead, two are nettle wine, one is poison, one turns back.
 Second from the left is not the forward potion.
 The forward potion is to the right of the poison.
 Nettle wine flanks the smallest bottle.
 The poison is in a round bottle.
 The forward potion is in the seventh position."
```
Correct bottle: VII (rightmost).

**Implementation:** `scripts/potions_puzzle.gd` as a self-contained CanvasLayer.

### room_4f — Upper Corridor (Peeves + Filch Patrol)

- **Peeves** (hostile NPC, WANDER + projectile) makes two appearances
  (positioned in the room as separate NPC instances).
  - Peeves fires water-balloon projectiles (low damage, short range).
  - Peeves has low HP (3) and can be chased off with melee hits.
- **Roaming Poltergeist Debris** (same type as room_4a): 2 enemies.
- Professor **McGonagall** (friendly NPC, STATIONARY at north door) gives a
  story hint:
  > *"What in Merlin's name are you doing out of bed?  …Never mind, just be
  >  careful what's at the top of the stairs."*
- North exit is always open after talking to McGonagall (conversation is
  required — she blocks the exit physically until her dialog ends).

### room_4g — Third-Floor Corridor (Quirrell Boss Arena)

- **Fluffy** is represented by a large non-interactive sprite (three grey
  ColorRects side-by-side) lying unconscious in the west corner.  It snores
  every few seconds (short dialog bubble: *"Zzzz…"* that pops and disappears).
- **Quirrell** boss instance using `boss_quirrell.tscn` (Task 07), positioned
  at the north end of the room.
- The room has no exits until the boss is defeated.
- On first entering the room, a brief cutscene (Task 02):
  1. Quirrell spins around, startled.
  2. Quirrell (arguing with himself): *"He's just a boy — I can see that,
     My Lord — no, no, deal with him — *fine*—"*
  3. Player regains control; boss fight begins.
- On boss defeat (`boss_defeated` signal):
  1. Boss death animation (flash + fade).
  2. Dumbledore arrival cinematic (Task 02): Dumbledore walks in from south.
  3. Dumbledore: *"Ah.  You must be the other Dursley.  I wondered when you'd
     turn up."*
  4. Epilogue cutscene (Task 01 slides) — Sorting Hat ceremony.
  5. Level 4 complete → credits / level-select.

---

## Intro Cutscene (Slides)

1. *"Hogwarts Castle.  Below ground.  The Tradesmen's Entrance."*
2. *"Someone came through here before Dudley.  Recently.  In a hurry."*
3. *"They left a trail of sprung traps, battered obstacles, and one enormous
   unconscious dog."*
4. *"Dudley follows it upward."*

---

## Epilogue Cutscene (Slides)

1. *"The Sorting Hat settles onto Dudley's head."*
2. *"A long pause."*
3. *"'Tenacious.  Loyal to a fault.  Not afraid of hard work when properly
   motivated…'"*
4. *"'Better be…'"*
5. *"HUFFLEPUFF."*
6. *"The Hufflepuff table erupts."*
7. *"Harry, at the Gryffindor table, turns around."*
8. *"Dudley gives a small, awkward wave."*
9. *"Harry, after a moment, waves back."*

---

## New Scenes and Scripts

| File | Notes |
|------|-------|
| `scenes/level4/room_4a.tscn` through `room_4g.tscn` | Seven rooms |
| `scripts/potions_puzzle.gd` | CanvasLayer bottle-select puzzle UI |
| `scenes/potions_puzzle.tscn` | Puzzle overlay scene |
| `scripts/main.gd` | Add `level_4` entry; connect boss_defeated |

---

## Adding to `main.gd`

```gdscript
"level_4": {
    "start_room": "room_4a",
    "start_pos": Vector2(320.0, 440.0),
    "next_level": "",  # last level
    "rooms": { ... },
    "connections": { ... },
},
```

---

## Art Notes (Placeholder)

- Stone dungeon: dark grey floor, stone-block walls.
- Devil's Snare: dark green vine overlay (ColorRect with transparency).
- Flying Keys: small yellow rectangles; correct key is larger, dark grey.
- Chess board: alternating light/dark grey 32×32 tiles; pieces are chess-piece
  colored rectangles.
- Potions: small cylindrical shapes (short wide ColorRects in various colors).
- Quirrell: beige NPC; Phase 3 add a "face" element at back (small dark sprite
  layered on the NPC).
- Fluffy: three large grey ColorRects in a row, lying flat.
