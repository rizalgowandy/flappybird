#!/usr/bin/env bash
# Headless autoplay test wrapper for the Flappy Bird project.
#
# Plays the game automatically and stops when the score target is reached or the
# time budget expires. Exits 0 on success (target reached), 1 on timeout.
#
# Usage:
#   test/run_autoplay.sh [TARGET_SCORE] [MINUTES]
#   test/run_autoplay.sh 50 3
#
# Env:
#   GODOT   Godot binary to use (default: godot-4)
set -euo pipefail

GODOT="${GODOT:-godot-4}"
TARGET="${1:-30}"
MINUTES="${2:-2}"

cd "$(dirname "$0")/.."

exec "$GODOT" --headless --path . --fixed-fps 60 res://test/autoplay.tscn -- \
	--target "$TARGET" --minutes "$MINUTES"
