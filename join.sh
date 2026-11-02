#!/usr/bin/env bash
# Starts Unreal Tournament and connects straight to the family server saved by setup.sh.
# Checks the server first and asks for its password when it has one (saved only on this PC),
# because a failed join at startup otherwise just drops you at the intro with no message.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")" && pwd)"
source "$repo_dir/lib.sh"
password_file="$repo_dir/.server-password"
game_log="$repo_dir/game/System64/UnrealTournament.log"

if [[ ! -s "$repo_dir/.server-address" ]]; then
    echo "No server address saved yet: run ./setup.sh and enter it when asked." >&2
    exit 1
fi
address=$(<"$repo_dir/.server-address")
host="${address%:*}"
game_port="${address##*:}"

echo "Checking the family server at $address..."
status=$(query_server_status "$host" "$((game_port + 1))")
if [[ -z "$status" ]]; then
    echo "The server at $address is not answering. Ask the host to start ./server.sh." >&2
    echo "(If the address changed, run ./setup.sh to enter the new one.)" >&2
    exit 1
fi

ask_for_password() {
    local password
    read -r -s -p "$1 (typing is hidden; saved only on this PC, Enter to skip): " password || true
    echo
    if [[ -n "$password" ]]; then
        printf '%s' "$password" > "$password_file"
        chmod 600 "$password_file"
    fi
}

if [[ ! -s "$password_file" && "$status" == *'\password\True'* ]]; then
    ask_for_password "This server needs a password"
    [[ -s "$password_file" ]] || { echo "No password entered." >&2; exit 1; }
fi
# A saved password is always sent: the server ignores it if it has none, and the status
# check above can miss the password flag when queried several times in a row.
url="$address"
[[ -s "$password_file" ]] && url="$address?password=$(<"$password_file")"

rm -f "$game_log"
"$repo_dir/play.sh" "$url" || true

rejection=$(grep -a 'PendingLevel received: FAILURE' "$game_log" 2>/dev/null | tail -1 | sed 's/.*FAILURE //' || true)
if [[ -n "$rejection" ]]; then
    echo "The server turned you away: $rejection" >&2
    if grep -aqE 'FAILCODE (NEEDPW|WRONGPW)' "$game_log"; then
        rm -f "$password_file"
        ask_for_password "Enter the server password to save it for next time"
        echo "Run ./join.sh again to connect." >&2
    fi
    exit 1
fi
