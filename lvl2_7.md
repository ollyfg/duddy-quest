# Level 2 Task 7 — Ollivander's wand shop and wand acquisition

## Context

This is the key story moment of Level 2. After obtaining wizard money
from Gringotts, Dudley visits Ollivander's where a wand chooses him.
The wand acquisition enables ranged attacks (`V` key) for the rest of
the game.

## Requirements

### Room layout (`l2_ollivanders.tscn`)
- Narrow, dusty shop interior with towering shelves of wand boxes
- West exit → `l2_diagon_alley_north` (entry from street)
- No other exits (player leaves back through the street)
- Shelves as obstacles along both walls, narrow centre aisle

### Mr Ollivander NPC
- Friendly NPC, `npc_name`: `"Mr Ollivander"`
- Positioned deep in the shop (player must walk past shelves)

### Wand acquisition cinematic

On first interaction with Ollivander (flag `l2_wand_acquired` not set):

1. **Dialog**: "Hmm... a Muggle-born, are you? Most unusual."
2. **Cinematic**: Ollivander walks to a shelf, pauses
3. **Dialog**: "Maple and unicorn tail-hair. Eight and three-quarter
   inches. Quite inflexible."
4. **Dialog**: "Rather like its new owner, I suspect."
5. **Cinematic**: A golden flash effect (screen flash, similar to rage
   but gold-coloured)
6. **Dialog**: "A promising start."
7. **Effect**: Player receives wand item → `player.has_wand = true`
8. **Flag**: Set `l2_has_wand` and `l2_wand_acquired`
9. **HUD update**: Wand icon appears (existing `_on_wand_acquired` flow)

### Post-acquisition dialog
- Repeat interaction: "Take care of that wand, boy. It chose you."
- Ollivander remains in the shop for the rest of the level

### Implementation notes
- The wand item in Level 1 is given by picking up an `Item` node. For
  this scene, the wand is given through dialog/cinematic, not a floor
  pickup. The cinematic's `on_finish` callback should set `has_wand`
  on the player and emit `wand_acquired`.
- The golden flash can reuse the rage flash effect in `main.gd`
  (`_on_rage_attack`) with a gold colour override.

## Acceptance criteria

- [ ] Ollivander dialog plays the full wand-choosing sequence
- [ ] Player receives the wand — ranged attack (`V`) now works
- [ ] Wand HUD indicator appears
- [ ] Golden flash effect plays during cinematic
- [ ] `l2_has_wand` flag set (triggers post-wand pixie encounter)
- [ ] Repeat visits show different dialog
- [ ] Room entry blocked until `l2_has_wizard_money` flag is set
