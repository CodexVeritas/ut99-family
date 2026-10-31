#!/usr/bin/env bash
# Runs the family server in this terminal; closing the terminal or pressing Ctrl+C stops it.
# Optional argument: a different map/game, e.g. ./server.sh "CTF-Face?game=Botpack.CTFGame"
set -euo pipefail
server_url="${1:-DM-lol-Harbour?game=Botpack.DeathMatchPlus?mutator=BotPack.LowGrav,StuffSwapper.StuffSwapper}"
cd "$(dirname "$0")/game/System64" 2>/dev/null || { echo "Game not installed yet: run ./setup.sh first." >&2; exit 1; }
echo "Starting the family server on UDP port 7777 (players connect to this PC's public address)."
echo "To stop it: press Ctrl+C or close this window."
exec ./ucc-bin server "$server_url" ini=Server.ini userini=ServerUser.ini -nohomedir
