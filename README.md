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
├── PLOT.md                # Full game narrative and level design document
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
│   ├── boss_quirrell.tscn # Professor Quirrell boss scene
│   ├── room_a.tscn        # Training room 1 (friendly NPC, east exit)
│   ├── room_b.tscn        # Training room 2 (hostile enemy)
│   ├── room_c.tscn        # Training room 3
│   ├── room_d.tscn        # Training room 4
│   ├── l1_bedroom.tscn    # Level 1: Dudley's bedroom
│   ├── l1_upper_hall.tscn # Level 1: upper hallway
│   ├── l1_hallway.tscn    # Level 1: main hallway (Petunia patrol)
│   ├── l1_front_hall.tscn # Level 1: front hall
│   ├── l1_garden.tscn     # Level 1: garden (Mrs Figg / cats puzzle)
│   └── l1_street.tscn     # Level 1: street / level exit
├── scripts/
│   ├── main.gd            # Game controller: room/level loading & transitions
│   ├── player.gd          # Player movement, melee, ranged attack, HP, rage
│   ├── npc.gd             # NPC AI (wander/chase/patrol/keep-distance), dialog
│   ├── projectile.gd      # Projectile movement, collision, deflection
│   ├── room.gd            # Room exit detection, switch/key logic, NPC helpers
│   ├── dialog_box.gd      # Multi-line NPC conversation display with choices
│   ├── game_state.gd      # Autoload: persists level selection & completion flags
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
│   ├── boss.gd            # Phase-based boss base class (extends npc.gd)
│   ├── boss_quirrell.gd   # Quirrell boss configuration (3 phases)
│   └── grid_overlay.gd    # Debug: transparent 16 px grid overlay
└── assets/                # Game assets (images, audio, fonts)
```

## Features

- **Scene flow**: Title screen → level select → game.  On death or level complete the player returns to the level select.  `GameState` (autoload) stores the selected level and completion flags across scene changes.
- **Levels**: Each level is defined in `scripts/main.gd` in the `LEVELS` dictionary, which groups rooms, connections, starting position, and display title.  Levels are unlocked sequentially from the level-select screen.
- **Movement**: WASD moves the player using Zelda-style 16 px grid steps.  Diagonal input is supported.  Knockback bypasses the grid for free movement.
- **Multiple rooms**: Rooms are connected via directional exits defined in `LEVELS["connections"]`.  Walk into an exit Area2D to transition.  New rooms can be added by extending the `LEVELS` dict in `scripts/main.gd`.
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
