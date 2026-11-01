#!/usr/bin/env bash
# Copies your current game settings (mods, presets, map rotations, key bindings) into config/
# so everyone gets them on their next ./update.sh. Your player profile, screen size, passwords,
# and server history are not shared. Asks before committing and pushing.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")" && pwd)"
source "$repo_dir/lib.sh"
system_dir="$repo_dir/game/System64"
config_dir="$repo_dir/config"

not_shared_ini_files=" unrealtournament.ini user.ini server.ini serveruser.ini default.ini defuser.ini unrealed.ini "

for process in ut-bin ut-bin-amd64 ucc-bin ucc-bin-amd64; do
    if pgrep -x "$process" >/dev/null; then
        echo "Quit the game and stop the server first: they save settings when they exit." >&2
        exit 1
    fi
done
[[ -f "$system_dir/UnrealTournament.ini" ]] || { echo "Game not installed yet: run ./setup.sh first." >&2; exit 1; }

staging_dir=$(mktemp -d)
trap 'rm -rf "$staging_dir"' EXIT
mkdir "$staging_dir/mods"

cp "$system_dir/UnrealTournament.ini" "$staging_dir/UnrealTournament.ini"
set_ini_value "$staging_dir/UnrealTournament.ini" SDLDrv.SDLClient FullscreenViewportX 1920
set_ini_value "$staging_dir/UnrealTournament.ini" SDLDrv.SDLClient FullscreenViewportY 1080
set_ini_value "$staging_dir/UnrealTournament.ini" Engine.GameInfo AdminPassword ""
set_ini_value "$staging_dir/UnrealTournament.ini" Engine.GameInfo GamePassword ""
set_ini_value "$staging_dir/UnrealTournament.ini" URL Host ""
sed -i -E 's/^((OpenHistory|Favorites)\[[0-9]+\])=.*/\1=/' "$staging_dir/UnrealTournament.ini"
sed -E 's/^ServerActors=IpServer\.UdpServerUplink /; ServerActors=IpServer.UdpServerUplink /' \
    "$staging_dir/UnrealTournament.ini" > "$staging_dir/Server.ini"

cp "$system_dir/User.ini" "$staging_dir/User.ini"
set_ini_value "$staging_dir/User.ini" DefaultPlayer Name Player

for file in "$system_dir"/*.ini; do
    name="${file##*/}"
    [[ "$not_shared_ini_files" == *" ${name,,} "* ]] && continue
    cp "$file" "$staging_dir/mods/$name"
done

ip_addresses=$(grep -rnE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' "$staging_dir" | grep -vE '\b(127\.0\.0\.1|0\.0\.0\.0)\b' | sed "s|$staging_dir/||" || true)
if [[ -n "$ip_addresses" ]]; then
    echo "Stopped: these settings contain IP addresses, which would be published in a public repo:" >&2
    echo "$ip_addresses" >&2
    echo "Remove them from the matching file in game/System64 (or ask for help), then run this again. Nothing was changed." >&2
    exit 1
fi

cp "$staging_dir"/*.ini "$config_dir/"
cp "$staging_dir"/mods/*.ini "$config_dir/mods/"

if [[ -z "$(git -C "$repo_dir" status --porcelain -- config)" ]]; then
    echo "No settings changed since the last publish."
    exit 0
fi
git -C "$repo_dir" status --short -- config
git -C "$repo_dir" diff --stat -- config
read -r -p "Publish these settings to everyone now (commit and push)? [y/N] " answer
if [[ "$answer" =~ ^[Yy] ]]; then
    git -C "$repo_dir" add config
    git -C "$repo_dir" commit -q -m "Update shared game settings"
    git -C "$repo_dir" push -q
    echo "Published. Everyone gets them with ./update.sh."
else
    echo "Not published. Review with 'git diff config'; undo with 'git checkout -- config'."
fi
