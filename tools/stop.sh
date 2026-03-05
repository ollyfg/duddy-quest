#!/usr/bin/env bash
# Stops the running Duddy Quest game and its Xvfb display.
#
# Usage:
#   bash tools/stop.sh

set -euo pipefail

GODOT_PID_FILE="/tmp/duddy_quest.pid"
XVFB_PID_FILE="/tmp/duddy_quest_xvfb.pid"

stopped_any=false

_kill_and_wait() {
    local pid="$1"
    local label="$2"
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        # Wait up to 5 s for the process to exit.
        local i=0
        while kill -0 "$pid" 2>/dev/null && [ $i -lt 50 ]; do
            sleep 0.1
            i=$((i + 1))
        done
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi
        echo "Stopped $label (PID $pid)"
        stopped_any=true
    fi
}

if [ -f "$GODOT_PID_FILE" ]; then
    pid="$(cat "$GODOT_PID_FILE")"
    _kill_and_wait "$pid" "game"
    rm -f "$GODOT_PID_FILE"
fi

if [ -f "$XVFB_PID_FILE" ]; then
    pid="$(cat "$XVFB_PID_FILE")"
    _kill_and_wait "$pid" "Xvfb"
    rm -f "$XVFB_PID_FILE"
fi

# Clean up stale IPC files.
rm -f /tmp/duddy_quest_cmd.json /tmp/duddy_quest_result.json

if [ "$stopped_any" = false ]; then
    echo "No running game found."
fi
