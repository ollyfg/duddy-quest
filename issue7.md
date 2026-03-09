# Issue 7 — Decouple item pickup effects from direct player property access

## Problem

`scripts/item.gd` directly modifies player internals on pickup:

```gdscript
player.hp += heal_amount        # line 34
player.has_wand = true           # line 36
player.inventory.append(key_id)  # line 38-39
```

This tight coupling means:

- Adding a new item type (e.g. shield, speed potion, map) requires
  editing `item.gd` *and* knowing the player's internal property names.
- If `player.gd` renames `inventory` to `_inventory` or changes HP to
  use a setter, every item breaks silently.
- Items cannot be reused for NPC drops, chest loot, or shop purchases
  because they assume the collector is always the player.

## Suggested approach

Define a pickup interface on the player (or any collector):

```gdscript
# player.gd
func collect_item(item_type: String, data: Dictionary) -> void:
    match item_type:
        "health": hp += data.get("amount", 1)
        "wand":   has_wand = true
        "key":    inventory.append(data.get("key_id", ""))
```

Then in `item.gd`:

```gdscript
func _on_body_entered(body: Node2D) -> void:
    if body.has_method("collect_item"):
        body.collect_item(type_name, {"amount": heal_amount, "key_id": key_id})
        queue_free()
```

This keeps item logic generic and testable without needing a real player
node.

## Acceptance criteria

- [ ] `item.gd` does not reference any `player.*` property directly
- [ ] Player exposes `collect_item()` method
- [ ] Existing item pickups work identically
- [ ] New item types can be added without editing `item.gd`
- [ ] Test added for `collect_item()` with mock data
