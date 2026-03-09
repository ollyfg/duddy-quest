# Level 2 Task 5 — Madam Malkin's robe shop and mannequin puzzle

## Context

Dudley needs Hogwarts robes but can't afford the quoted price. He must
retrieve a discount ledger knocked behind a display by Neville
Longbottom. Rotating mannequins block the path and will knock Dudley
off-course on contact.

## Requirements

### Room layout (`l2_madam_malkins.tscn`)
- Clothing shop interior: fabric rolls, mirrors, fitting stands
- East exit → `l2_diagon_alley_north`
- No other exits

### NPCs

**Madam Malkin** (friendly, behind counter):
- `npc_name`: `"Madam Malkin"`
- Initial dialog: "Hogwarts robes? That'll be 40 Galleons."
- After ledger retrieved (flag `l2_has_discount_ledger`):
  "Oh, the staff discount ledger! Fine — 12 Galleons."
- After purchase (flag `l2_has_robes`):
  "Looking sharp, dear. Off you go."

**Neville** (friendly, near display):
- `npc_name`: `"Neville"`
- Dialog: "S-sorry! I knocked something behind those mannequins."
- After ledger retrieved: "Oh good, you found it! I'm so clumsy..."
- Sets flag `l2_neville_spoke` on first interaction (hints the puzzle)

### Mannequin puzzle

- 3–4 mannequin obstacles arranged in a path between the shop floor and
  the back corner where the ledger item sits
- **Mannequin behaviour**: Each mannequin rotates in place on a timer
  (e.g. 90° every 1.5 seconds). When facing the player's path, its
  extended arm blocks passage (collision enabled). When rotated away,
  the path is clear.
- Implementation: Use a `StaticBody2D` with a `CollisionShape2D` that
  toggles `disabled` based on a rotation timer. Alternatively, use an
  `AnimatableBody2D` that physically sweeps.
- The player must time movement through gaps between mannequin rotations
- Consider creating a new `mannequin.gd` script for this behaviour

### Discount ledger item
- `Item` node (type: key) placed behind the mannequin gauntlet
- `key_id`: `"discount_ledger"`
- On pickup: sets flag `l2_has_discount_ledger`
- Madam Malkin's dialog changes to offer the discount price

### Purchase flow
- After getting ledger, talk to Madam Malkin → dialog option to purchase
- Sets flag `l2_has_robes`
- Robes are not a visible gameplay item — just a story flag

## Acceptance criteria

- [ ] Mannequins rotate on a timer, blocking/unblocking the path
- [ ] Player can time movement through the mannequin gauntlet
- [ ] Ledger item is collectible behind mannequins
- [ ] Madam Malkin dialog changes after ledger retrieval
- [ ] `l2_has_robes` flag set after purchase dialog
- [ ] Neville dialog provides puzzle hint
- [ ] `check_alignment.py` passes
