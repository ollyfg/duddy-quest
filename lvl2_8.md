# Level 2 Task 8 — Draco Malfoy miniboss fight

## Context

Draco Malfoy is the mid-level miniboss of Level 2. He confronts Dudley
in the alley after the wand acquisition, using jinxes borrowed from
Lucius's cane. Dudley must survive with melee and footwork (wand newly
acquired but Draco is immune to basic spells). Lucius watches from a
distance but does not intervene.

## Requirements

### Arena (`l2_alley_end.tscn`)
- Open street area with some barrel/crate obstacles for cover
- North area: Lucius Malfoy standing still (static, non-interactable
  decoration or friendly NPC with one-liner)
- Centre: Draco spawn point
- Level end trigger at the north edge (after Draco is defeated)

### Draco NPC (Boss)
- Use `boss.tscn` / `boss.gd` system (extends NPC with phases)
- `npc_name`: `"Draco Malfoy"`
- **Not a full boss fight** — simpler than Quirrell. 2 phases, lower HP.

| Phase | HP threshold | Behaviour | Shoot pattern |
|---|---|---|---|
| 1 | 6–4 HP | KEEP_DISTANCE, fires jinx projectiles | single |
| 2 | 3–0 HP | CHASE, faster movement, fires burst | burst |

- **HP**: 6 total
- **Move speed**: Phase 1: 70, Phase 2: 100
- **Shoot interval**: Phase 1: 2.0s, Phase 2: 1.2s
- **Contact damage**: 1 HP

### Draco-specific behaviour
- Create `boss_draco.gd` extending `boss.gd` (like `boss_quirrell.gd`)
- Phase data defined in `_ready()`
- On defeat: plays a flee cinematic
  1. Draco turns away: "My father will hear about this!"
  2. Draco NPC walks north off-screen and is freed
  3. Lucius shakes his head, walks north off-screen
- Sets flag `l2_draco_defeated`

### Lucius Malfoy NPC
- Static friendly NPC in the north of the arena
- `npc_name`: `"Lucius Malfoy"`
- Before fight: "..." (silent, watches)
- During fight: non-interactable (set `is_hostile = false`, no dialog
  trigger while boss is active)
- After fight: removed during flee cinematic

### Intro cinematic
- On first room entry (if `l2_has_wand` is set and `l2_draco_defeated`
  is not):
  1. Camera pans to Draco
  2. Dialog: "Well, well. A Muggle at Hogwarts. How revolting."
  3. Dialog: "Father's cane has a few tricks. Let me show you."
  4. Camera resets, boss fight begins

### Level end
- After Draco flees, a `LevelEndTrigger` activates at the north edge
- Walking into it triggers the Level 2 end cutscene (see Task 9)

## Acceptance criteria

- [ ] Draco has 2 phases with different movement and shooting
- [ ] Draco's jinx projectiles are dodge-able and deflectable
- [ ] Defeating Draco plays the flee cinematic
- [ ] `l2_draco_defeated` flag set after fight
- [ ] Level end trigger activates only after Draco is defeated
- [ ] Lucius is visible but non-interactable during the fight
- [ ] Boss HP bar or visual feedback shown during fight
