#!/usr/bin/env bash
# Starts Duddy Quest in a virtual framebuffer (Xvfb) with DevTools enabled.
#
# The DevTools autoload will listen for commands via file-based IPC:
#   Command file : /tmp/duddy_quest_cmd.json
#   Result file  : /tmp/duddy_quest_result.json
#
# Usage:
#   bash tools/launch.sh
#
# Options (environment variables):
#   GODOT_BIN     Path to the Godot executable (default: auto-detected)
#   DISPLAY_NUM   Xvfb display number         (default: 99)
#   GAME_WIDTH    Virtual display width        (default: 640)
#   GAME_HEIGHT   Virtual display height       (default: 480)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DISPLAY_NUM="${DISPLAY_NUM:-99}"
GAME_WIDTH="${GAME_WIDTH:-640}"
GAME_HEIGHT="${GAME_HEIGHT:-480}"

GODOT_PID_FILE="/tmp/duddy_quest.pid"
XVFB_PID_FILE="/tmp/duddy_quest_xvfb.pid"

# ---------------------------------------------------------------------------
# Find the Godot binary
# ---------------------------------------------------------------------------
find_godot() {
    # 1. Explicit override
    if [ -n "${GODOT_BIN:-}" ]; then
        echo "$GODOT_BIN"
        return
    fi
    # 2. Binary downloaded by install_godot.sh
    if [ -x "$SCRIPT_DIR/godot4" ]; then
        echo "$SCRIPT_DIR/godot4"
        return
    fi
    # 3. System PATH
    for name in godot4 godot; do
        if command -v "$name" &>/dev/null; then
            echo "$name"
            return
        fi
    done
    echo ""
}

GODOT="$(find_godot)"
if [ -z "$GODOT" ]; then
    echo "ERROR: Godot executable not found." >&2
    echo "  Run: bash tools/install_godot.sh" >&2
    echo "  Or set: export GODOT_BIN=/path/to/godot4" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Check that Xvfb is available
# ---------------------------------------------------------------------------
if ! command -v Xvfb &>/dev/null; then
    echo "ERROR: Xvfb not found. Install it with: sudo apt install xvfb" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Bail out if already running
# ---------------------------------------------------------------------------
if [ -f "$GODOT_PID_FILE" ] && kill -0 "$(cat "$GODOT_PID_FILE")" 2>/dev/null; then
    echo "Game is already running (PID $(cat "$GODOT_PID_FILE")). Run tools/stop.sh first."
    exit 0
fi

# ---------------------------------------------------------------------------
# Start Xvfb (nohup so it survives when the calling shell exits)
# ---------------------------------------------------------------------------
nohup Xvfb ":$DISPLAY_NUM" -screen 0 "${GAME_WIDTH}x${GAME_HEIGHT}x24" \
    > /tmp/duddy_quest_xvfb.log 2>&1 &
XVFB_PID=$!
echo "$XVFB_PID" > "$XVFB_PID_FILE"
echo "Xvfb started on display :$DISPLAY_NUM (PID $XVFB_PID)"
sleep 0.5   # Give Xvfb a moment to initialise

# ---------------------------------------------------------------------------
# Import project (generates .godot/ UID cache needed to resolve scene UIDs)
# ---------------------------------------------------------------------------
if [ ! -f "$PROJECT_DIR/.godot/uid_cache.bin" ]; then
    echo "Importing project (first-time setup)..."
    "$GODOT" --headless --editor --quit --path "$PROJECT_DIR" 2>&1 \
        | grep -v "^$" || true
    echo "Import complete."
fi

# ---------------------------------------------------------------------------
# Start Godot (nohup ensures it outlives the calling interactive shell)
# ---------------------------------------------------------------------------
nohup env DISPLAY=":$DISPLAY_NUM" "$GODOT" --path "$PROJECT_DIR" -- --dev-tools \
    > /tmp/duddy_quest_godot.log 2>&1 &
GODOT_PID=$!
echo "$GODOT_PID" > "$GODOT_PID_FILE"

echo "Duddy Quest launched (PID $GODOT_PID)"
echo "DevTools IPC files:"
echo "  Command : /tmp/duddy_quest_cmd.json"
echo "  Result  : /tmp/duddy_quest_result.json"
echo ""
echo "Wait ~3 seconds before sending the first command."
echo "Use 'python3 tools/playtest.py --help' to see available commands."
echo "Stop with: bash tools/stop.sh"
