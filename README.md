# duddy-quest

A Godot 4 top-down roguelike, in the style of early Legend of Zelda games.  It follows Dudley Dursley from Harry Potter on his unusual journey to get to Hogwarts.  The game features melee combat (his Smeltings Stick) and a wand that fires ranged spells.

## Requirements

- [Godot Engine 4.x](https://godotengine.org/download/)

## Getting Started

1. Open Godot Engine
2. Click **Import** and navigate to this directory
3. Select `project.godot` to open the project
4. Press **F5** (or click the Play button) to run the game

## Controls

| Key | Action |
|-----|--------|
| **W / A / S / D** | Move up / left / down / right |
| **C** | Melee attack (Smeltings Stick swing) |
| **V** | Ranged attack (fire wand projectile) |
| **E** | Interact (unused; NPC dialog triggers on collision) |
| **Walk into NPC** | Start conversation |

## Project Structure

```
duddy-quest/
├── project.godot          # Godot project configuration
├── icon.svg               # Application icon
├── export_presets.cfg     # Godot export presets (Web, Desktop)
├── PLOT.md                # Full game narrative and level design document
├── AGENTS.md              # Playtesting tool documentation
├── data/
│   ├── level_1.json       # Level 1 room/connection definitions
│   └── level_2.json       # Level 2 room/connection definitions
├── scenes/
│   ├── main.tscn          # Root game scene (game controller, HUD)
│   ├── player.tscn        # Player character
│   ├── npc.tscn           # NPC / enemy (reused for both friendly and hostile)
│   ├── projectile.tscn    # Player / enemy projectile
│   ├── dialog_box.tscn    # NPC conversation UI overlay
│   ├── title_screen.tscn  # Title screen
│   ├── level_select.tscn  # Level selection screen
│   ├── level_complete.tscn# Level-complete overlay
│   ├── cutscene.tscn      # Slide-show cutscene overlay
│   ├── mobile_controls.tscn # On-screen touch control overlay
│   ├── item.tscn          # Pickable item (health, wand, key)
│   ├── locked_door.tscn   # Key-locked door
│   ├── magic_door.tscn    # Rage-breakable magic door
│   ├── switch.tscn        # Hit-to-toggle switch (opens doors / exits)
│   ├── torch.tscn         # Lightable torch (lights Devil's Snare)
│   ├── light_source.tscn  # Generic timed light source node
│   ├── devils_snare.tscn  # Light-sensitive obstacle
│   ├── pushable_block.tscn# Pushable chess piece / block
│   ├── push_puzzle_trigger.tscn # Detects when pushed blocks reach targets
│   ├── level_end_trigger.tscn   # Area that ends the current level
│   ├── mannequin.tscn     # Rotating mannequin obstacle
│   ├── boss_quirrell.tscn # Professor Quirrell boss scene
│   ├── boss_draco.tscn    # Draco Malfoy miniboss scene
│   ├── flying_letter.tscn # Flying letter effect
│   ├── l1_bedroom.tscn    # Level 1: Dudley's bedroom
│   ├── l1_dining_room.tscn# Level 1: dining room
│   ├── l1_upper_hall.tscn # Level 1: upper hallway
│   ├── l1_hallway.tscn    # Level 1: main hallway (Petunia patrol)
│   ├── l1_front_hall.tscn # Level 1: front hall
│   ├── l1_vernon_room.tscn# Level 1: Vernon's room
│   ├── l1_garden.tscn     # Level 1: garden (Mrs Figg / cats puzzle)
│   ├── l1_street.tscn     # Level 1: street / level exit
│   ├── l2_leaky_cauldron.tscn    # Level 2: Leaky Cauldron (start)
│   ├── l2_diagon_alley_south.tscn# Level 2: Diagon Alley south
│   ├── l2_diagon_alley_north.tscn# Level 2: Diagon Alley north
│   ├── l2_gringotts.tscn  # Level 2: Gringotts bank
│   ├── l2_madam_malkins.tscn # Level 2: Madam Malkin's
│   ├── l2_ollivanders.tscn# Level 2: Ollivanders
│   ├── l2_menagerie.tscn  # Level 2: Menagerie
│   └── l2_alley_end.tscn  # Level 2: end of alley
├── scripts/
│   ├── main.gd            # Thin game coordinator; loads level data from JSON
│   ├── room_manager.gd    # Room lifecycle, loading, transitions, A* pathfinding
│   ├── dialog_manager.gd  # NPC conversations, post-dialog effects
│   ├── hud_manager.gd     # HP hearts, key counter, rage bar, wand display
│   ├── level_manager.gd   # Level loading, intro cinematics, level-end cutscenes
│   ├── player.gd          # Player movement, melee, ranged attack, HP, rage
│   ├── npc.gd             # NPC AI (wander/chase/patrol/keep-distance), dialog
│   ├── projectile.gd      # Projectile movement, collision, deflection
│   ├── room.gd            # Room exit detection, switch/key logic, NPC helpers
│   ├── dialog_box.gd      # Multi-line NPC conversation display with choices
│   ├── game_state.gd      # Autoload: persists level selection & completion flags
│   ├── config.gd          # **Designer tuning hub**: all gameplay constants
│   ├── dev_tools.gd       # Autoload: file-IPC server for automated playtesting
│   ├── mobile_controls.gd # Touch overlay: simulates keyboard input actions
│   ├── title_screen.gd    # Title screen logic
│   ├── level_select.gd    # Level selection screen logic
│   ├── level_complete.gd  # Level-complete overlay logic
│   ├── cutscene.gd        # Slide-show cutscene player
│   ├── cinematic_player.gd# In-game cinematic sequence runner
│   ├── item.gd            # Pickup item (health, wand, key) logic
│   ├── locked_door.gd     # Key-locked door logic
│   ├── magic_door.gd      # Rage-breakable magic door logic
│   ├── switch.gd          # Melee-toggled switch logic
│   ├── torch.gd           # Lightable torch logic
│   ├── light_source.gd    # Generic timed light source (used by torches)
│   ├── devils_snare.gd    # Light-sensitive obstacle logic
│   ├── pushable_block.gd  # Pushable block / chess piece logic
│   ├── push_puzzle_trigger.gd # Block-on-target puzzle solver
│   ├── level_end_trigger.gd   # Level end area logic
│   ├── mannequin.gd       # Rotating mannequin obstacle logic
│   ├── boss.gd            # Phase-based boss base class (extends npc.gd)
│   ├── boss_quirrell.gd   # Quirrell boss configuration (3 phases)
│   ├── boss_draco.gd      # Draco Malfoy miniboss configuration
│   ├── combat_utils.gd    # Shared combat utilities
│   ├── pathfinder.gd      # RoomPathfinder wrapping AStarGrid2D for 16px grid
│   ├── navigation_utils.gd# Navigation utilities
│   ├── flying_letter.gd   # Flying letter animation
│   ├── flying_letters_container.gd # Flying letter container
│   └── grid_overlay.gd    # Debug: transparent 16 px grid overlay
├── tests/                 # GUT unit tests (9 test files)
├── tools/                 # Playtesting and development utilities (see AGENTS.md)
├── hooks/                 # Git hooks (pre-commit: VERSION bump + grid check + tests)
├── addons/gut/            # GUT testing framework
└── assets/                # Game assets (images, audio, fonts)
```

## Features

- **Scene flow**: Title screen → level select → game.  On death or level complete the player returns to the level select.  `GameState` (autoload) stores the selected level and completion flags across scene changes.
- **Levels**: Each level is defined in a JSON file under `data/` (e.g. `data/level_1.json`), which defines rooms, connections, starting position, and display title.  `main.gd` loads these at init.  Levels are unlocked sequentially from the level-select screen.
- **Movement**: WASD moves the player using Zelda-style 16 px grid steps.  Diagonal input is supported.  Knockback bypasses the grid for free movement.
- **Multiple rooms**: Rooms are connected via directional exits defined in `data/*.json`.  Walk into an exit Area2D to transition.  New rooms can be added by extending the level JSON files.
- **Melee combat**: Press **C** to swing the Smeltings Stick.  The Area2D hitbox activates briefly in the facing direction and damages anything it touches (1 HP).  Enemies and the player are knocked back on hit.  0.5 s cooldown.
- **Ranged combat**: Press **V** to fire a wand projectile in the facing direction (requires the wand item to be collected first).  Projectiles despawn on hitting a wall or target, dealing 1 HP damage.  0.4 s cooldown.  Player projectiles can be deflected by melee-hitting enemy deflectable shots.
- **Rage mechanic**: Each melee swing builds the rage meter by 0.2; it decays at 0.05/s.  When the meter fills it triggers a spinning AoE rage attack (radius 64 px) that deals 2 HP and breaks objects in the `"breakable"` group.
- **NPC conversations**: Walk into a friendly NPC (blue) to start a dialog.  A dialog panel appears at the bottom; press **C** or **V** (or tap **Next**) to advance lines.  Dialogs support branching choices, key giving/accepting, and game-flag gating.
- **Keys & locked exits**: Key items can be collected and spent to unlock exits or doors.  Exit keys are defined per-room; locked door keys are consumed on use.
- **Enemies**: Hostile NPCs (red) use configurable AI modes — chase, keep-distance, wander, or patrol — and damage the player on contact.  Some can fire projectiles.
- **Boss fights**: Bosses extend the base NPC with phase transitions, configurable shoot patterns (single / burst / arc sweep), and deflectable projectiles.
- **Cutscenes & cinematics**: Slide-show cutscenes play at level start/end.  In-game cinematic sequences can move NPCs and the player programmatically.
- **Mobile controls**: An on-screen touch overlay simulates all keyboard actions on touchscreen devices.
- **Playtesting tools**: Headless automated playtesting via `tools/launch.sh` and `tools/playtest.py` (see `AGENTS.md` for full documentation).
- **Gameplay tuning**: All numeric constants (speeds, ranges, timings, probabilities) are centralised in `scripts/config.gd` (`GameConfig`).  Edit that file to adjust any value without grepping the codebase.

## Architecture Red Flags (Scalability Watchlist)

The current implementation works well for a small game, but these areas are the
main growth risks for larger content-heavy Zelda-style development:

1. **High dependence on hardcoded scene node paths**  
   Logic in `room_manager.gd` and `room.gd` repeatedly queries `"NPCs"`, `"Items"`,
   `"Switches"`, `"Doors/Door_*"`, `"ExitEast"` style names.  Scene hierarchy
   refactors become brittle because gameplay logic depends on exact node names.

2. **NPC dialog gating is tightly encoded in one function**  
   Dialog gating logic in `dialog_manager.gd` hardcodes priority/branching for keys and
   flags.  New gate types (quests, stats, time/stateful conditions) currently
   require editing central game logic instead of composing reusable conditions.

3. **Some core gameplay constants are duplicated per-script**  
   Knockback and room-bound assumptions are embedded in multiple scripts (e.g.
   `player.gd`/`npc.gd`).  A shared tuning/config source (`config.gd`) exists
   but not all values have been migrated.

### Completed refactors

- ✅ **Split `main.gd` into managers**: `main.gd` is now a thin coordinator (~300 lines).
  Room transitions, dialog orchestration, HUD, and level progression each live in their
  own manager script (`room_manager.gd`, `dialog_manager.gd`, `hud_manager.gd`,
  `level_manager.gd`).
- ✅ **Data-driven levels**: Level topology has been moved from code into `data/*.json` files.
- ✅ **Centralised config**: `scripts/config.gd` (`GameConfig`) consolidates gameplay
  constants (speeds, ranges, timings).

### Suggested next refactor order

1. Introduce room/NPC helper APIs (or cached node references) to reduce direct
   string-path lookups.
2. Extract reusable dialog condition evaluators.
3. Migrate remaining hardcoded constants into `config.gd`.

## Testing

The project uses the **GUT** (Godot Unit Test) framework. Test files live in `tests/` and
the addon lives in `addons/gut/`.

```bash
bash tools/install_godot.sh    # one-time: downloads Godot 4.6.1
bash tools/run_tests.sh        # runs all GUT tests
```

## CI / CD

- **GitHub Actions** (`.github/workflows/web-build.yml`): Builds the game for web and deploys to GitHub Pages on every push to `main`.
- **Pre-commit hook** (`hooks/pre-commit`, installed via `bash tools/install-hooks.sh`): Enforces VERSION bump in `scripts/game_state.gd`, 16px grid alignment, and passing GUT tests before every commit.
