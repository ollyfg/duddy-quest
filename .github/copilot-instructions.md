# Copilot Coding Agent Instructions

## Project Summary

**Duddy Quest** is a Godot 4.6 top-down roguelike game written entirely in GDScript. It is styled after early *Legend of Zelda* games and follows Dudley Dursley on his journey to Hogwarts. The player uses melee combat (Smeltings Stick) and ranged spells (wand). The project has ~39 source scripts (~4,600 lines of GDScript), ~39 scenes, and 2 playable levels.

## Technology

- **Engine**: Godot 4.6.1 (GDScript, no C# or GDNative)
- **Viewport**: 640 × 770 (portrait)
- **Renderer**: Mobile (2D-only)
- **Language**: GDScript only — all logic lives in `scripts/`
- **Scenes**: Stored as `.tscn` text files in `scenes/`
- **Level data**: Stored as JSON files in `data/` (data-driven room/connection definitions)
- **Testing**: GUT (Godot Unit Test) framework in `addons/gut/`; 9 test files in `tests/`
- **CI**: GitHub Actions workflow `web-build.yml` deploys to GitHub Pages on push to `main`
- **No external build tool**: the Godot editor/binary handles everything

## Project Layout

```
project.godot            # Godot project config (input map, autoloads, display)
icon.svg                 # Application icon
export_presets.cfg       # Godot export presets (Web, Desktop)
AGENTS.md                # Playtesting tool documentation
PLOT.md                  # Full game narrative and level design document
README.md                # Project overview and getting started guide

data/
  level_1.json           # Level 1 rooms, connections, start position
  level_2.json           # Level 2 rooms, connections, start position

scenes/
  # Core UI & screens
  main.tscn              # Root game scene (game controller, HUD, managers)
  title_screen.tscn      # Title screen (main entry point)
  level_select.tscn      # Level selection screen
  level_complete.tscn    # Level-complete overlay
  dialog_box.tscn        # NPC conversation UI overlay
  mobile_controls.tscn   # Touch control overlay
  cutscene.tscn          # Slide-show cutscene overlay
  # Player & combat
  player.tscn            # Player character (CharacterBody2D)
  npc.tscn               # NPC / enemy (reused for friendly and hostile)
  projectile.tscn        # Projectile
  boss_quirrell.tscn     # Quirrell boss
  boss_draco.tscn        # Draco miniboss
  flying_letter.tscn     # Flying letter effect
  # Game objects & puzzles
  item.tscn              # Pickable item (health, wand, key)
  locked_door.tscn       # Key-locked door
  magic_door.tscn        # Rage-breakable magic door
  switch.tscn            # Hit-to-toggle switch
  torch.tscn             # Lightable torch
  light_source.tscn      # Generic timed light source
  devils_snare.tscn      # Light-sensitive obstacle
  pushable_block.tscn    # Pushable chess piece / block
  push_puzzle_trigger.tscn # Block-on-target puzzle solver
  level_end_trigger.tscn # Level exit area
  mannequin.tscn         # Rotating mannequin obstacle
  # Level 1 rooms (8)
  l1_bedroom.tscn        l1_dining_room.tscn   l1_upper_hall.tscn
  l1_hallway.tscn        l1_front_hall.tscn     l1_vernon_room.tscn
  l1_garden.tscn         l1_street.tscn
  # Level 2 rooms (8)
  l2_leaky_cauldron.tscn l2_diagon_alley_south.tscn l2_diagon_alley_north.tscn
  l2_gringotts.tscn      l2_madam_malkins.tscn      l2_ollivanders.tscn
  l2_menagerie.tscn      l2_alley_end.tscn

scripts/
  # Core game controller & managers
  main.gd                # Thin coordinator (~300 lines); loads level data from JSON
  room_manager.gd        # Room lifecycle, loading, transitions, A* pathfinding
  dialog_manager.gd      # NPC conversations, post-dialog effects, locked-exit messages
  hud_manager.gd         # HP hearts, key counter, rage bar, wand display, game-over
  level_manager.gd       # Level loading, intro cinematics, level-end cutscenes
  # Player & combat
  player.gd              # Movement, melee, ranged attack, HP, rage meter, knockback
  npc.gd                 # NPC AI (wander/chase/patrol/keep-distance/cone), dialog, HP
  projectile.gd          # Projectile movement, collision, deflection
  boss.gd                # Phase-based boss base class (extends npc.gd)
  boss_quirrell.gd       # Quirrell boss (3 phases)
  boss_draco.gd          # Draco miniboss
  combat_utils.gd        # Shared combat utilities
  # Room & navigation
  room.gd                # Exit detection, switch/key logic, flag-based exit locking
  pathfinder.gd          # RoomPathfinder wrapping AStarGrid2D for 16px grid
  navigation_utils.gd    # Navigation utilities
  # UI & systems
  dialog_box.gd          # Multi-line dialog display with branching choices
  game_state.gd          # Autoload: persists level selection, completion flags, story flags
  dev_tools.gd           # Autoload: file-IPC server for headless playtesting (--dev-tools only)
  config.gd              # GameConfig: centralised gameplay constants (speeds, ranges, timings)
  mobile_controls.gd     # Touch overlay simulating keyboard input
  title_screen.gd        # Title screen logic
  level_select.gd        # Level selection logic
  level_complete.gd      # Level-complete overlay logic
  # Game objects
  item.gd                locked_door.gd       magic_door.gd
  switch.gd              torch.gd             light_source.gd
  devils_snare.gd        pushable_block.gd    push_puzzle_trigger.gd
  level_end_trigger.gd   mannequin.gd
  # Cinematics & effects
  cutscene.gd            cinematic_player.gd
  flying_letter.gd       flying_letters_container.gd
  grid_overlay.gd        # Debug: transparent 16px grid overlay

tools/
  install_godot.sh       # Downloads Godot 4.6.1 binary to tools/godot4
  launch.sh              # Starts Xvfb (:99) + Godot with --dev-tools flag
  stop.sh                # Kills Godot and Xvfb, removes IPC files
  playtest.py            # Python IPC client (CLI and library) for automated playtesting
  run_tests.sh           # Runs GUT unit tests
  install-hooks.sh       # Configures git to use committed hooks
  check_alignment.py     # Validates room nodes are on 16px grid
  check_rooms.py         # Room configuration validation

tests/                   # GUT unit tests (9 files)
hooks/
  pre-commit             # Enforces VERSION bump, grid alignment, and passing tests
addons/gut/              # GUT testing framework
assets/                  # Images, audio, fonts
```

## Key Architectural Patterns

- **Manager architecture**: `scripts/main.gd` is a thin coordinator (~300 lines). Logic is delegated to four child-node managers: `room_manager.gd`, `dialog_manager.gd`, `hud_manager.gd`, and `level_manager.gd`. Each has a `setup()` method.
- **Data-driven levels**: Level topology is defined in `data/level_1.json` and `data/level_2.json` (rooms, connections, start positions). `main.gd` loads these in `_init()` into a `LEVELS` dictionary.
- **Signals**:
  - `player.gd` emits `hp_changed`, `died`, `wand_acquired`, `keys_changed`, `rage_changed`, `rage_attack`
  - `npc.gd` emits `interaction_requested`, `player_detected`, `player_hit`, `damaged`
  - `room.gd` emits `exit_triggered(direction)`, `locked_exit_attempted(direction, required_key)`
- **Input actions** (defined in `project.godot`):
  | Action | Key | Description |
  |---|---|---|
  | `move_up` | W | Move up |
  | `move_down` | S | Move down |
  | `move_left` | A | Move left |
  | `move_right` | D | Move right |
  | `melee_attack` | C | Swing Smeltings Stick |
  | `ranged_attack` | V | Fire projectile |
  | `interact` | E | Open locked doors, advance cutscenes/level-complete screen |
- **Knockback**: Both `player.gd` and `npc.gd` have `apply_knockback(direction)` and `_knockback_velocity` that decays via `move_toward` each frame.
- **NPC duality**: A single `npc.tscn` / `npc.gd` handles both friendly and hostile NPCs via the `is_hostile` export. AI modes include wander, chase, patrol, keep-distance, and cone detection.
- **Boss system**: `boss.gd` extends `npc.gd` with phase transitions, configurable shoot patterns (single/burst/arc), and deflectable projectiles. `boss_quirrell.gd` and `boss_draco.gd` extend it.
- **GameConfig**: All numeric constants (speeds, ranges, timings) are centralised in `scripts/config.gd`. Edit that file instead of grepping individual scripts.
- **GameState autoload**: `game_state.gd` persists selected level, completed levels, story flags (e.g. `l1_has_wand`, `l2_has_wizard_money`), and inventory across scene changes.
- **Flag-based gating**: Room exits can be locked behind GameState flags via `flag_east`/`flag_west`/etc. exports on `room.gd`. Dialog options can set/remove flags.
- **Pathfinding**: `pathfinder.gd` wraps `AStarGrid2D` for 16px grid rooms. NPCs use it when `use_astar=true`; cinematics use it for `move_node()`.
- **DevTools autoload**: `dev_tools.gd` is registered as an autoload in `project.godot` but only activates when `--dev-tools` is in the command-line arguments (passed after `--`).

## Running Tests

The project uses the **GUT** (Godot Unit Test) framework with 9 test files in `tests/`.

```bash
bash tools/install_godot.sh    # one-time: downloads Godot 4.6.1
bash tools/run_tests.sh        # runs all GUT tests
```

## Running and Playtesting

In addition to unit tests, the game can be validated by running it headlessly and observing behaviour via the DevTools IPC system.

### Prerequisites

```bash
sudo apt install xvfb          # virtual framebuffer for headless rendering
bash tools/install_godot.sh    # downloads Godot 4.6.1 to tools/godot4
```

### Launch (headless)

```bash
bash tools/launch.sh           # starts Xvfb on :99 and Godot with --dev-tools
python3 tools/playtest.py wait # block until DevTools IPC is ready (~3 s)
```

`launch.sh` automatically runs `godot --headless --editor --quit --path .` the first time to generate `.godot/uid_cache.bin` (required for scene UID resolution).

### Playtest commands

```bash
python3 tools/playtest.py screenshot /tmp/view.png      # capture viewport
python3 tools/playtest.py input move_right 2.0          # hold action for 2 s
python3 tools/playtest.py release move_right            # release held action
python3 tools/playtest.py state                         # JSON: player pos/hp, room, NPCs
python3 tools/playtest.py wait                          # wait for DevTools to respond
python3 tools/playtest.py spawn --room l1_hallway --x 100 --y 200  # teleport player
python3 tools/playtest.py mobile-viewport on            # toggle mobile viewport
```

### Stop

```bash
bash tools/stop.sh
```

## CI / Validation

A GitHub Actions workflow (`.github/workflows/web-build.yml`) builds the game for web and deploys to GitHub Pages on every push to `main`.

A pre-commit hook (`hooks/pre-commit`, installed via `bash tools/install-hooks.sh`) enforces:
1. VERSION bump in `scripts/game_state.gd` relative to `origin/main`
2. Grid alignment of room nodes (16px grid)
3. All GUT tests passing

When making changes, validate with:
1. Run unit tests: `bash tools/run_tests.sh`
2. Launch the game headlessly: `bash tools/launch.sh`
3. Wait for DevTools: `python3 tools/playtest.py wait`
4. Take a screenshot to verify the initial state: `python3 tools/playtest.py screenshot /tmp/before.png`
5. Exercise the changed code path using `playtest.py input` commands
6. Take a follow-up screenshot and check `playtest.py state` to verify correctness
7. Stop the game: `bash tools/stop.sh`

## Version Bumping

Every PR must bump the `VERSION` constant in `scripts/game_state.gd`. The pre-commit hook will block commits if the version has not changed relative to `origin/main`.

## Editing Scenes

Prefer editing `.tscn` files through the Godot editor. If you must edit them as text, note that they use a Godot-specific text format; node properties are defined with `[node name="..." type="..."]` sections. UIDs in `uid://` references must match entries in `.godot/uid_cache.bin` (auto-generated on import).

## GDScript Conventions Used in This Project

- Static typing is used throughout (`var x: float`, `func foo(a: int) -> void`).
- `@onready` is used to cache child-node references.
- `@export` is used for designer-configurable properties (e.g. `is_hostile`, `dialog_lines`).
- Constants are `ALL_CAPS`; member variables are `snake_case`; private vars are prefixed `_`.
- `queue_free()` is used to remove nodes; `await get_tree().process_frame` is used after freeing to avoid use-after-free.
