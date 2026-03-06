#!/usr/bin/env bash
# Configures this repository to use the committed hooks in the hooks/ directory.
# Run once from the repo root after cloning:
#
#   bash tools/install-hooks.sh

set -e
REPO_ROOT="$(git rev-parse --show-toplevel)"
git -C "$REPO_ROOT" config core.hooksPath hooks
echo "✅  Git hooks installed. hooks/ will be used for all git operations in this repo."
