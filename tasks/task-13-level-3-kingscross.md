# Task 13 — Level 3: *Platform 9¾ … and a Half* (King's Cross & The Maintenance Express)

## Summary
Build Level 3, set first on the platform at King's Cross and then aboard the
Hogwarts Maintenance Express.  Three distinct puzzle types — a constraint-matching
puzzle, a timing-based corridor, and an item-distraction puzzle — are introduced
alongside two new enemy types: a Boggart and Enchanted Suits of Armour.

---

## Prerequisites (must be merged first)

| Task | Feature needed |
|------|---------------|
| Task 01 | Cutscene panels for level intro and outro |
| Task 02 | Cinematic: Fred and George wave Dudley onto the wrong train |
| Task 06 | Level completion trigger (train arrives at Hogwarts) |

---

## Level Structure

```
[Intro cutscene — King's Cross; Fred & George cinematic]
    │
    ▼
room_3a — Platform 9¾½  (Fred & George cinematic; board the train)
    │ east exit (train door)
    ▼
room_3b — Train Corridor A  (Trolley Witch PATROL; normal movement)
    │ east exit
    ▼
room_3c — Cargo Car — Mandrake Puzzle  (wailing NPCs; pot-matching puzzle UI)
    │ east exit (after puzzle solved)
    ▼
room_3d — Moving Corridor  (timed door pattern; timing puzzle)
    │ east exit (after navigating corridor)
    ▼
room_3e — Luggage Car  (Boggart enemy; Peeves' crate distraction puzzle)
    │ east exit (after Boggart defeated + Peeves distracted)
    ▼
room_3f — Train Front Cab  (Enchanted Armour combat; redirect train route)
    │ north exit (train platform, level end)
    ▼
[Outro cutscene: "HOGWARTS (TRADESMEN'S ENTRANCE)" → Level 3 Complete]
```

---

## Room Specifications

### room_3a — Platform 9¾½

**Intro cinematic (Task 02):**
- Fred Weasley and George Weasley (two friendly NPCs) stand on the platform.
- Scripted sequence:
  1. Fred: *"You've missed the Hogwarts Express.  Tragedy."*
  2. George: *"Fortunately there's another service.  Platform 9¾½."*
  3. Fred: *"Completely reliable."*
  4. George: *"We'd get on it ourselves but…"* (Fred and George exchange a look
     and back away off screen.)
  5. A train (large sprite entering from east) shudders to a halt.
  6. Trolley Witch leans out: *"Anything off the trolley, dears?"*
- Player regains control; east exit leads onto the train.

### room_3b — Train Corridor A

- Long horizontal room.
- **Trolley Witch** (friendly NPC, PATROL mode, east–west) selling sweets from
  a cart.  She is non-hostile but blocks the path when in front of her cart.
- Neville Longbottom (friendly, STATIONARY) sits in a compartment worrying
  about Trevor.  Dialog hint: *"Trevor got on by accident.  I think he's in the
  cargo car."*
- East exit leads to room_3c.

### room_3c — Cargo Car (Mandrake Puzzle)

**Puzzle: Match Mandrakes to pots.**

This is a **menu-based puzzle** (not a spatial one):

1. When the player steps into the room, a wailing SFX plays and a "puzzle
   overlay" is shown (CanvasLayer) with a simple matching UI:
   - Three Mandrake silhouettes (labeled by leaf shape: Curly, Straight, Spiky).
   - Three pot sizes (Small, Medium, Large).
   - Drag-and-drop (or arrow-key + confirm) to assign each Mandrake to a pot.
   - Constraint text shown: *"No two Mandrakes of the same age may share a pot."*
   - Care card fragment showing which leaf shape corresponds to which age
     (Curly = young, Straight = medium, Spiky = old).

2. Valid solution: no two Mandrakes share a pot, and each is in an
   appropriately sized pot (young → small, medium → medium, old → large).
   There is exactly one valid assignment.

3. On correct solution: wailing stops, puzzle overlay closes, east exit enables.
   On incorrect attempt: a shake animation and a hint dialog:
   > "The care card says: never mix two Mandrakes of the same age…"

**Implementation:** Create `scripts/mandrake_puzzle.gd` (a self-contained
CanvasLayer UI) invoked from room_3c's `_ready()`.

### room_3d — Moving Corridor (Timing Puzzle)

- A narrow room divided into four sections by sliding walls.
- Each sliding wall cycles: open (passable) for 3 seconds, closed (blocking)
  for 3 seconds.  The walls are offset by 1.5 seconds each so only one gap is
  open at a time.
- Player must sprint through each section during its open window.
  If caught by a closing wall, the player is pushed back to the section start
  (no damage).
- Walls are `AnimatableBody2D` nodes with a looping tween.
- East exit is always open; the challenge is reaching it in time.

### room_3e — Luggage Car (Boggart + Peeves Distraction)

**Boggart enemy:**
- A new enemy type `scenes/boggart.tscn` / `scripts/boggart.gd`.
- The Boggart lurks in the luggage rack.  When the player enters its detection
  range it jumps down and becomes active.
- **Shape-shifting:** The Boggart cycles through a list of forms every 5 seconds
  (Boggart has `@export var forms: Array[Dictionary]` where each dict has
  `{ "color": Color, "speed": float, "can_shoot": bool }`).
- Its final form (when `hp <= 1`): it becomes **Aunt Petunia** (a pink NPC
  with a feather duster as a projectile) and is momentarily stunned for 1 second
  — giving the player a window to land a finishing blow.
- The Boggart should be defeatable primarily with melee (its HP pool: 5).

**Peeves distraction puzzle:**
- Peeves' crate (`StaticBody2D` + dialog trigger) is in the corner.
- Peeves is lobbing water balloons (projectiles) that spawn from the crate
  position and travel in random directions, dealing 1 damage on contact.
- Nearby on the floor is a copy of *Which Broomstick?* magazine (KEY item,
  key_id = `"which_broomstick"`).
- An interactable "slot" on the crate (press `interact` while adjacent) accepts
  the magazine: if the player is carrying the magazine, a short animation plays
  and Peeves goes quiet (balloons stop, east exit unlocks).

### room_3f — Train Front Cab (Armour Combat)

- Two **Enchanted Suits of Armour** (hostile NPC, CHASE, high HP = 8, slow
  move speed, deal 2 damage on contact, no ranged attack).
- A **control panel** (interactable switch) at the far east end redirects the
  train route.  It can only be interacted with after both armour suits are defeated
  (use a RoomClearTrigger watching the `"armour"` group).
- Interacting with the panel triggers:
  1. A brief screen shake.
  2. Peeves (now freed and floating) appears: *"Ickle Duddy's here!"* (dialog).
  3. The north exit (level-end trigger) activates.

---

## Intro Cutscene (Slides)

1. *"King's Cross Station."*
2. *"Dudley arrived with four minutes to spare and missed the Hogwarts Express
   entirely while arguing about Cornish pasties."*
3. *"Fred and George Weasley had also missed it.  Long story."*

---

## Outro Cutscene (Slides)

1. *"The train shudders to a halt."*
2. *"A mossy stone platform.  A sign reads: HOGWARTS (TRADESMEN'S ENTRANCE)."*
3. *"Peeves floats gleefully overhead: 'Ickle Duddy's here, ickle Duddy's here!'"*

---

## New Scenes and Scripts

| File | Notes |
|------|-------|
| `scenes/level3/room_3a.tscn` through `room_3f.tscn` | Six rooms |
| `scripts/boggart.gd` | Extends npc.gd; shape-shifting enemy |
| `scenes/boggart.tscn` | Boggart enemy scene |
| `scripts/mandrake_puzzle.gd` | CanvasLayer matching-puzzle UI |
| `scenes/mandrake_puzzle.tscn` | Puzzle overlay scene |
| `scripts/main.gd` | Add `level_3` entry |

---

## Adding to `main.gd`

```gdscript
"level_3": {
    "start_room": "room_3a",
    "start_pos": Vector2(64.0, 240.0),
    "next_level": "level_4",
    "rooms": { ... },
    "connections": { ... },
},
```

---

## Art Notes (Placeholder)

- Platform: grey tile floor, station pillars.
- Train carriages: dark brown walls, small windows.
- Cargo car: wooden crates (brown rectangles), Mandrake pots (terracotta circles).
- Moving walls: dark grey rectangles with animated position.
- Boggart: dark purple shifting shape; Petunia form: pink/lilac.
- Enchanted Armour: grey rectangle, slow, large collision.
