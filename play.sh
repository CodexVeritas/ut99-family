#!/usr/bin/env bash
# Starts Unreal Tournament. Extra arguments go to the game, e.g. a server address to join.
# The fullscreen size is matched to the current screen first: a mismatch (e.g. a laptop
# undocked from a bigger monitor) makes the game draw into only part of the screen.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")" && pwd)"
source "$repo_dir/lib.sh"
cd "$repo_dir/game/System64" 2>/dev/null || { echo "Game not installed yet: run ./setup.sh first." >&2; exit 1; }

screen_resolution=$(detect_resolution)
if [[ -n "$screen_resolution" ]]; then
    set_ini_value UnrealTournament.ini SDLDrv.SDLClient FullscreenViewportX "${screen_resolution%x*}"
    set_ini_value UnrealTournament.ini SDLDrv.SDLClient FullscreenViewportY "${screen_resolution#*x}"
fi

exec ./ut-bin "$@" -nohomedir
