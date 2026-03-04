# duddy-quest

A Godot 4 game project.

Played as a top-down rouguelike, in the style of early legend of zelda games. It is based on the adoptive brother Dudley from Harry Potter, and follows his unusual journey to get to Hogwarts. The game features melee weapons (his Smeltings Stick), and eventually a wand that fires ranged spells.

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
| **Z** | Melee attack (Smeltings Stick swing) |
| **X** | Ranged attack (fire projectile) |
| **E** | Interact (talk to nearby NPC) |

## Project Structure

```
duddy-quest/
├── project.godot          # Godot project configuration
├── icon.svg               # Application icon
├── scenes/
│   ├── main.tscn          # Root game scene (game controller, HUD)
│   ├── player.tscn        # Player character
│   ├── npc.tscn           # NPC / enemy (reused for both friendly and hostile)
│   ├── projectile.tscn    # Player / enemy projectile
│   ├── dialog_box.tscn    # NPC conversation UI overlay
│   ├── room_a.tscn        # First room (friendly NPC, east exit)
│   └── room_b.tscn        # Second room (enemy, west exit back to room_a)
├── scripts/
│   ├── main.gd            # Game controller: room loading & transitions
│   ├── player.gd          # Player movement, melee, ranged attack, HP
│   ├── npc.gd             # NPC AI (wander / chase), dialog, HP
│   ├── projectile.gd      # Projectile movement & collision
│   ├── room.gd            # Room exit detection, NPC helpers
│   └── dialog_box.gd      # Multi-line NPC conversation display
└── assets/                # Game assets (images, audio, etc.)
```

## Gameplay Scaffold Features

- **Movement**: WASD moves the player in 8 directions through rooms with solid walls.
- **Multiple Rooms**: Walk east in Room A to enter Room B; walk west in Room B to return. New rooms can be added in `scripts/main.gd` (`ROOMS` and `ROOM_CONNECTIONS`).
- **Melee combat**: Press **Z** to swing the Smeltings Stick. The Area2D hitbox activates briefly in the facing direction and damages any enemy it touches (1 HP). 0.5 s cooldown.
- **Ranged combat**: Press **X** to fire a projectile in the facing direction. Projectiles despawn on hitting a wall or enemy, dealing 1 HP damage. 0.4 s cooldown.
- **NPC conversations**: Walk up to the friendly NPC (blue square) in Room A and press **E**. A dialog panel appears at the bottom of the screen; press **Next** to advance lines and **Close** to dismiss.
- **Enemies**: Room B contains a red enemy that chases the player. It damages the player on contact. It can be killed with melee or ranged attacks.
