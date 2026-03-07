#!/usr/bin/env bash
# Run the GUT test suite headlessly and return a non-zero exit code on failure.
#
# Usage (from the repo root):
#   bash tools/run_tests.sh
#
# Prerequisites:
#   bash tools/install_godot.sh   # download Godot binary to tools/godot4
#
# The script uses the .gutconfig.json at the repo root, which points GUT at the
# tests/ directory with should_exit=true so Godot quits automatically once all
# tests finish.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GODOT_BIN="${GODOT_BIN:-$SCRIPT_DIR/godot4}"

if [ ! -x "$GODOT_BIN" ]; then
    echo "❌  Godot binary not found at $GODOT_BIN"
    echo "    Run:  bash tools/install_godot.sh"
    exit 1
fi

# First import pass: generate UID cache and import resources so GUT can load
# all scenes and scripts without errors.  Only needed the very first time (or
# after a clean checkout); subsequent runs skip this because godot4 --headless
# --editor --quit detects that imports are up-to-date.
if [ ! -f "$REPO_ROOT/.godot/uid_cache.bin" ]; then
    echo "Running first-time import..."
    "$GODOT_BIN" --headless --editor --quit --path "$REPO_ROOT" 2>&1 | tail -5 || true
fi

echo "Running GUT tests..."
"$GODOT_BIN" --headless --path "$REPO_ROOT" -s addons/gut/gut_cmdln.gd \
    -gconfig=.gutconfig.json \
    -gexit 2>&1
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅  All GUT tests passed."
else
    echo "❌  GUT tests failed (exit code: $EXIT_CODE)."
fi

exit $EXIT_CODE
