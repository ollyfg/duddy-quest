# Task 05 — KEY Item Type + Key-Locked Exits and Doors

## Summary
Add a `KEY` item type to the item system and the ability to lock exits (and
optional door objects in a room) so they only open when the player is carrying
the matching key.

---

## Motivation (from the plot)

- **Level 1:** Dudley's bus fare is tucked under Mr Tibbles' collar.  He needs
  it to board the bus (the level-end trigger).
- **Level 2:** The Gringotts vault requires a key (the letter contains a vault
  number); this is resolved through dialogue, but the concept of "carry a key
  to unlock a passage" is reused elsewhere.
- **Level 4:** The flying-keys chamber has a locked door that requires the
  specific iron key to be knocked out of the air and picked up.

---

## Acceptance Criteria

### Item Changes

1. `item.gd` gains a new enum value: `ItemType.KEY`.
2. Keys have a designer-set `key_id: String` export:
   ```gdscript
   @export var key_id: String = "key_default"
   ```
3. When a KEY item is picked up, it is added to `player.inventory` (see below)
   rather than immediately consumed.
4. KEY items render as a small yellow rectangle (distinct from health red and
   wand purple).

### Player Inventory

5. `player.gd` gains:
   ```gdscript
   var inventory: Array[String] = []   # list of key_ids held by the player
   func has_key(key_id: String) -> bool
   func remove_key(key_id: String) -> void
   ```
6. Inventory persists across room transitions (it lives on the player node
   which is never freed between rooms).

### Locked Exits

7. `room.gd` Exit nodes gain an optional export:
   ```gdscript
   @export var required_key: String = ""   # empty = unlocked
   ```
8. When `required_key` is non-empty, the exit only triggers if
   `player.has_key(required_key)` is true.  On success the key is consumed
   (`player.remove_key`).  On failure a brief "It's locked." dialog line is
   shown via the existing dialog box.

### Locked Door Objects (optional visual)

9. A new scene `scenes/locked_door.tscn` with script `scripts/locked_door.gd`
   provides a visible door obstacle:
   - `@export var required_key: String`
   - A `StaticBody2D` collision shape that blocks movement while locked.
   - Visually: a dark rectangle with a small keyhole sprite (or colored shape).
   - On player contact: shows "Locked." in the dialog box.
   - When the player presses `interact` while adjacent and holding the right
     key, the door opens (collision disabled, visual changes to open).
   - Emits `signal door_opened(key_id: String)`.

### HUD

10. The HUD in `main.tscn` shows a simple key icon + count (e.g. `🗝 2`) when
    the player holds any keys.  The display updates whenever `inventory` changes.
    Add a `key_count_label: Label` to the HUD and a `keys_changed` signal to
    `player.gd`.

---

## Implementation Notes

- Keep inventory as a plain `Array[String]` (key IDs) rather than a custom
  Resource; this is sufficient for the game's needs.
- The locked-door scene reuses the `StaticBody2D` + `CollisionShape2D` pattern
  already used by walls in rooms.
- `room.gd` Exit area already handles `exit_triggered`; just add the key check
  inside `_on_body_entered` before emitting the signal.

---

## Dependencies

None.  (Task 09 flying-keys combat uses KEY items but can be built independently
once this task is done.)

---

## Files to Create / Modify

| File | Action |
|------|--------|
| `scripts/item.gd` | Add `KEY` enum, `key_id` export, inventory pickup |
| `scripts/player.gd` | Add `inventory`, `has_key()`, `remove_key()`, `keys_changed` signal |
| `scripts/room.gd` | Add `required_key` to Exit, check before emitting |
| `scenes/locked_door.tscn` | Create |
| `scripts/locked_door.gd` | Create |
| `scenes/main.tscn` | Add key-count HUD label |
| `scripts/main.gd` | Wire `keys_changed` to HUD update |
