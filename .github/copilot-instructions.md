# Copilot Coding Agent Instructions

## Project Summary

**Duddy Quest** is a Godot 4.6 top-down roguelike game written entirely in GDScript. It is styled after early *Legend of Zelda* games and follows Dudley Dursley on his journey to Hogwarts. The player uses melee combat (Smeltings Stick) and ranged spells (wand). The project is small (~15 source files, ~650 lines of GDScript).

## Technology

- **Engine**: Godot 4.6.1 (GDScript, no C# or GDNative)
- **Viewport**: 640 × 480
- **Renderer**: Mobile (2D-only)
- **Language**: GDScript only — all logic lives in `scripts/`
- **Scenes**: Stored as `.tscn` text files in `scenes/`
- **No external build tool**: the Godot editor/binary handles everything

## Project Layout

```
project.godot          # Godot project config (input map, autoloads, display)
icon.svg               # Application icon
scenes/
  main.tscn            # Root scene (Node2D + scripts/main.gd); game controller & HUD
  player.tscn          # Player character (CharacterBody2D + scripts/player.gd)
  npc.tscn             # NPC / enemy, reused for friendly and hostile (scripts/npc.gd)
  projectile.tscn      # Projectile (scripts/projectile.gd)
  dialog_box.tscn      # NPC dialog overlay (scripts/dialog_box.gd)
  l1_bedroom.tscn      # Level 1: Dudley's bedroom
  l1_hallway.tscn      # Level 1: main hallway
scripts/
  main.gd              # Room loading/transitions; defines ROOMS and ROOM_CONNECTIONS dicts
  player.gd            # Movement, melee (MeleeArea), ranged attack, HP, knockback
  npc.gd               # Wander/chase AI, dialog, HP, knockback
  projectile.gd        # Projectile movement and collision
  room.gd              # Exit detection (exit_triggered signal), NPC helpers
  dialog_box.gd        # Multi-line dialog display; advances with melee_attack or ranged_attack
  dev_tools.gd         # DevTools autoload — file-IPC for headless playtesting (only active with --dev-tools flag)
tools/
  install_godot.sh     # Downloads Godot 4.6.1 binary to tools/godot4
  launch.sh            # Starts Xvfb (:99) + Godot with --dev-tools flag; imports project if needed
  stop.sh              # Kills Godot and Xvfb, removes IPC files
  playtest.py          # Python IPC client (CLI and library) for automated playtesting
assets/                # Images, audio, etc.
AGENTS.md              # Playtesting tool documentation (same content as below)
```

## Key Architectural Patterns

- **Room management**: `scripts/main.gd` holds `ROOMS` (name → PackedScene) and `ROOM_CONNECTIONS` (name → direction → {room, entry}). To add a room, add an entry to both dicts.
- **Signals**: `player.gd` emits `hp_changed(new_hp)` and `died`. `npc.gd` emits `interaction_requested`. `room.gd` emits `exit_triggered(direction)`.
- **Input actions** (defined in `project.godot`):
  | Action | Key | Description |
  |---|---|---|
  | `move_up` | W | Move up |
  | `move_down` | S | Move down |
  | `move_left` | A | Move left |
  | `move_right` | D | Move right |
  | `melee_attack` | C | Swing Smeltings Stick |
  | `ranged_attack` | V | Fire projectile |
  | `interact` | E | Interact (currently unused; NPC dialog triggers on collision) |
- **Knockback**: Both `player.gd` and `npc.gd` have `apply_knockback(direction)` and `_knockback_velocity` that decays via `move_toward` each frame.
- **NPC duality**: A single `npc.tscn` / `npc.gd` handles both friendly (blue, wanders, triggers dialog on contact) and hostile (red, chases player, damages on contact) NPCs via the `is_hostile` export.
- **DevTools autoload**: `dev_tools.gd` is registered as an autoload in `project.godot` but only activates when `--dev-tools` is in the command-line arguments (passed after `--`).

## Running and Playtesting

There is **no automated test suite**. Validation is done by running the game and observing behaviour.

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
python3 tools/playtest.py state                         # JSON: player pos/hp, room name
python3 tools/playtest.py wait                          # wait for DevTools to respond
```

### Stop

```bash
bash tools/stop.sh
```

## CI / Validation

There are **no GitHub Actions workflows** in this repository. The only validation is manual playtesting using the tools above. When making changes:

1. Launch the game headlessly with `bash tools/launch.sh`.
2. Wait for DevTools: `python3 tools/playtest.py wait`.
3. Take a screenshot to verify the initial state: `python3 tools/playtest.py screenshot /tmp/before.png`.
4. Exercise the changed code path using `playtest.py input` commands.
5. Take a follow-up screenshot and check `playtest.py state` to verify correctness.
6. Stop the game with `bash tools/stop.sh`.

## Editing Scenes

Prefer editing `.tscn` files through the Godot editor. If you must edit them as text, note that they use a Godot-specific text format; node properties are defined with `[node name="..." type="..."]` sections. UIDs in `uid://` references must match entries in `.godot/uid_cache.bin` (auto-generated on import).

## GDScript Conventions Used in This Project

- Static typing is used throughout (`var x: float`, `func foo(a: int) -> void`).
- `@onready` is used to cache child-node references.
- `@export` is used for designer-configurable properties (e.g. `is_hostile`, `dialog_lines`).
- Constants are `ALL_CAPS`; member variables are `snake_case`; private vars are prefixed `_`.
- `queue_free()` is used to remove nodes; `await get_tree().process_frame` is used after freeing to avoid use-after-free.
