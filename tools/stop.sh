#!/usr/bin/env bash
# Stops the running Duddy Quest game and its Xvfb display.
#
# Usage:
#   bash tools/stop.sh

set -euo pipefail

GODOT_PID_FILE="/tmp/duddy_quest.pid"
XVFB_PID_FILE="/tmp/duddy_quest_xvfb.pid"

stopped_any=false

if [ -f "$GODOT_PID_FILE" ]; then
    pid="$(cat "$GODOT_PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        echo "Stopped game (PID $pid)"
        stopped_any=true
    fi
    rm -f "$GODOT_PID_FILE"
fi

if [ -f "$XVFB_PID_FILE" ]; then
    pid="$(cat "$XVFB_PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid"
        echo "Stopped Xvfb (PID $pid)"
        stopped_any=true
    fi
    rm -f "$XVFB_PID_FILE"
fi

# Clean up stale IPC files.
rm -f /tmp/duddy_quest_cmd.json /tmp/duddy_quest_result.json

if [ "$stopped_any" = false ]; then
    echo "No running game found."
fi
