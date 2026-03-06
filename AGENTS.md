You are an experienced Godot game developer. You are developing this game.
Played as a top-down roguelike, in the style of early legend of zelda games. It is based on the adoptive brother Dudley from Harry Potter, and follows his unusual journey to get to Hogwarts. The game features melee weapons (his Smeltings Stick), and eventually a wand that fires ranged spells.

## First-time setup (recommended)

Run this **once** immediately after cloning, before making any commits:

```bash
bash tools/install-hooks.sh
```

This configures git to use the committed hooks in `hooks/`.  The most
important hook is `hooks/pre-commit`, which blocks commits where the
`VERSION` constant in `scripts/game_state.gd` has not been bumped relative
to `origin/main`.  The hook gracefully skips if `origin/main` is not
reachable (e.g. in offline environments).

> **Every PR must bump the version.**  If a commit is blocked with
> `❌ VERSION has not been bumped`, update `VERSION` in
> `scripts/game_state.gd` (e.g. `"0.2.0"` → `"0.3.0"`) and retry.

## Playtesting Tools

The `tools/` directory contains scripts that allow you to launch, control, and observe
the game for automated playtesting and development.

### Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| Godot 4.6 | Run the game | See below |
| Xvfb | Virtual display (headless rendering) | `sudo apt install xvfb` |
| Python 3.8+ | Playtest client | Usually pre-installed |

### 1 – Install Godot 4.6

Run the helper script to download the official Godot 4.6 Linux binary to `tools/godot4`:

```bash
bash tools/install_godot.sh
```

Or point at an existing installation:

```bash
export GODOT_BIN=/path/to/godot4   # or godot, godot-4, etc.
```

### 2 – Launch the game headlessly

```bash
bash tools/launch.sh
```

This starts a virtual framebuffer (Xvfb on display `:99`) and then launches
Godot with the `--dev-tools` flag.  The DevTools autoload inside the game
activates, ready to receive commands.

PIDs are saved to `/tmp/duddy_quest.pid` and `/tmp/duddy_quest_xvfb.pid`.

Wait ~3 seconds after launching before sending the first command so that
the engine has time to load the main scene.

```bash
python3 tools/playtest.py wait       # blocks until DevTools responds
```

> **⚠️ Agent / scripted use: always detach the process.**
> Both Xvfb and Godot are started with `nohup` inside `launch.sh`, so they
> survive when the calling shell exits.  However, when using the `bash` tool
> from an agent context you **must** launch with `detach: true` (or via
> `mode="async", detach=true`) so that the process group is fully detached via
> `setsid`.  Without this the entire process group (Godot + Xvfb) will be
> killed when the agent's shell session ends.
>
> **Correct agent launch pattern:**
> ```
> # bash tool call: command="bash tools/launch.sh", mode="async", detach=true
> ```
> Then in a separate bash call (mode="sync"):
> ```bash
> python3 tools/playtest.py wait   # block until DevTools is ready
> ```

### 3 – Take a screenshot

```bash
python3 tools/playtest.py screenshot                # saved to /tmp/duddy_screenshot_<timestamp>.png
python3 tools/playtest.py screenshot /tmp/view.png  # explicit path
```

The PNG is captured from the Godot viewport (i.e. exactly what the player
would see on screen).

### 4 – Send input to the game

```bash
# Single-frame press (moves the player one step)
python3 tools/playtest.py input move_right

# Hold for a duration then auto-release (walk right for 2 seconds)
python3 tools/playtest.py input move_right 2.0

# Manually release a held action
python3 tools/playtest.py release move_right
```

> **⚠️ Always release inputs before pressing them again.**
> An `input` command without a `duration` leaves the action held until an explicit
> `release` is sent.  Godot's `is_action_just_pressed()` only fires on the first
> frame the action becomes pressed — it will **not** fire again while the action is
> still held.  This means repeating an `input` call without a `release` in between
> has **no effect** the second time.
>
> Whenever you need to press the same action more than once (e.g. advancing through
> multiple dialog lines with `melee_attack`), always interleave a `release`:
>
> ```bash
> python3 tools/playtest.py input  melee_attack   # press  → advances line 1
> python3 tools/playtest.py release melee_attack  # release
> python3 tools/playtest.py input  melee_attack   # press  → advances line 2
> python3 tools/playtest.py release melee_attack  # release
> ```
>
> Using `input <action> <duration>` is the safest approach for movement because
> it auto-releases after the timer expires, but you must still wait (`sleep`) for
> at least the duration before sending the next command.

Available input actions (defined in `project.godot`):

| Action | Default key | Effect |
|--------|------------|--------|
| `move_up` | W | Move up |
| `move_down` | S | Move down |
| `move_left` | A | Move left |
| `move_right` | D | Move right |
| `melee_attack` | C | Swing Smeltings Stick |
| `ranged_attack` | V | Fire projectile |

### 5 – Query game state

```bash
python3 tools/playtest.py state
```

Returns JSON like:

```json
{
  "player": { "x": 100.0, "y": 240.0, "hp": 5 },
  "room": "room_a"
}
```

### 6 – Stop the game

```bash
bash tools/stop.sh
```

Kills both the Godot process and the Xvfb display, and removes stale IPC files.

---

### Using playtest.py as a Python library

```python
import sys
sys.path.insert(0, "/path/to/duddy-quest")
from tools.playtest import PlaytestClient

client = PlaytestClient()

# Wait for the game to finish loading
client.wait_for_devtools()

# Walk right for 1.5 seconds
client.send_input("move_right", duration=1.5)

# Take a screenshot to see where we are
path = client.screenshot("/tmp/after_walk.png")
print("Saved:", path)

# Check player health and position
state = client.state()
print(state["player"])   # {"x": ..., "y": ..., "hp": ...}
```

### How it works (IPC protocol)

The `DevTools` node (autoload in `scripts/dev_tools.gd`) is loaded by Godot
only when `--dev-tools` is present in the user command-line arguments (passed
after the `--` separator in `tools/launch.sh`).

Once active it polls `/tmp/duddy_quest_cmd.json` every 50 ms.  When a file
appears the node executes the command and writes the result to
`/tmp/duddy_quest_result.json`.  `playtest.py` writes the command and waits for
the result file, then removes both files before the next request.

Supported command types:

```jsonc
// Take a viewport screenshot
{ "type": "screenshot", "path": "/tmp/shot.png" }

// Inject or release an input action
{ "type": "input", "action": "move_right", "pressed": true, "duration": 1.0 }

// Query game state
{ "type": "state" }
```

