#!/usr/bin/env bash
# Starts Unreal Tournament. Extra arguments go to the game, e.g. a server address to join.
set -euo pipefail
cd "$(dirname "$0")/game/System64" 2>/dev/null || { echo "Game not installed yet: run ./setup.sh first." >&2; exit 1; }
exec ./ut-bin "$@" -nohomedir
