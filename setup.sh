#!/usr/bin/env bash
# Installs Unreal Tournament GOTY (OldUnreal 469e) with the family mod pack into ./game,
# then asks for your player profile. Safe to re-run: finished steps are skipped.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")" && pwd)"
game_dir="$repo_dir/game"
download_dir="$repo_dir/downloads"
system_dir="$game_dir/System64"

iso_sha256="e184984ca88f001c5ddd52035d76cd64e266e26c74975161b5ed72366c74704f"
iso_urls=(
    "https://files.oldunreal.net/UT_GOTY_CD1.ISO"
    "https://files2.oldunreal.net/UT_GOTY_CD1.ISO"
    "https://files3.oldunreal.net/UT_GOTY_CD1.ISO"
    "https://archive.org/download/ut-goty/UT_GOTY_CD1.iso"
)
patch_file="OldUnreal-UTPatch469e-Linux-amd64.tar.bz2"
patch_url="https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469e/$patch_file"
patch_sha256="08c806aa3721b1970045aa158ad90051329d982e8a9a3661153900e9ccbf6b0c"
pack_release_url="https://github.com/CodexVeritas/ut99-family/releases/download/content-v1"

step() { printf '\n==> %s\n' "$*"; }
fail() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -m)" == "x86_64" ]] || fail "This setup only supports 64-bit Intel/AMD PCs (x86_64)."

has_library() { ldconfig -p 2>/dev/null | grep -q "$1"; }

install_dependencies() {
    step "Checking required system packages"
    local missing=()
    if command -v apt-get >/dev/null; then
        command -v curl >/dev/null || missing+=(curl)
        command -v bsdtar >/dev/null || missing+=(libarchive-tools)
        command -v zstd >/dev/null || missing+=(zstd)
        command -v bzip2 >/dev/null || missing+=(bzip2)
        has_library libSDL2-2.0.so.0 || missing+=(libsdl2-2.0-0)
        has_library libopenal.so.1 || missing+=(libopenal1)
        if ((${#missing[@]})); then
            echo "Installing: ${missing[*]} (you may be asked for your password)"
            sudo apt-get update && sudo apt-get install -y "${missing[@]}"
        fi
    elif command -v pacman >/dev/null; then
        command -v curl >/dev/null || missing+=(curl)
        command -v bsdtar >/dev/null || missing+=(libarchive)
        command -v zstd >/dev/null || missing+=(zstd)
        command -v bzip2 >/dev/null || missing+=(bzip2)
        has_library libSDL2-2.0.so.0 || missing+=(sdl2-compat)
        has_library libopenal.so.1 || missing+=(openal)
        if ((${#missing[@]})); then
            echo "Installing: ${missing[*]} (you may be asked for your password)"
            sudo pacman -S --needed --noconfirm "${missing[@]}"
        fi
    else
        fail "Unsupported Linux distribution: need apt (Ubuntu/Debian) or pacman (Arch/Omarchy)."
    fi
    echo "All required packages are installed."
}

download_verified() {
    local destination="$1" expected_sha256="$2"
    shift 2
    if [[ -f "$destination" ]] && echo "$expected_sha256  $destination" | sha256sum -c --quiet - 2>/dev/null; then
        echo "Already downloaded: ${destination##*/}"
        return
    fi
    local url
    for url in "$@"; do
        echo "Downloading ${destination##*/} from $url"
        if curl -L --fail --progress-bar -o "$destination.partial" "$url"; then
            if echo "$expected_sha256  $destination.partial" | sha256sum -c --quiet -; then
                mv "$destination.partial" "$destination"
                return
            fi
            echo "Checksum mismatch, trying next source..."
        fi
    done
    rm -f "$destination.partial"
    fail "Could not download ${destination##*/}"
}

install_base_game() {
    if [[ -f "$game_dir/.base-installed" ]]; then
        echo "Base game already installed."
        return
    fi
    step "Downloading the base game (650 MB, from OldUnreal's official mirror)"
    download_verified "$download_dir/UT_GOTY_CD1.iso" "$iso_sha256" "${iso_urls[@]}"

    step "Extracting the base game"
    mkdir -p "$game_dir"
    bsdtar -xf "$download_dir/UT_GOTY_CD1.iso" -C "$game_dir" \
        --exclude 'System/UnrealTournament.ini' --exclude 'System/User.ini' \
        --exclude 'System/*.bat' --exclude 'System/*.dll' --exclude 'System/*.exe' \
        --exclude 'System/*.int' --exclude 'System/*.?tt' \
        Maps Music Sounds Textures System Help Web
    chmod -R u+w "$game_dir"

    step "Downloading the OldUnreal 469e patch"
    download_verified "$download_dir/$patch_file" "$patch_sha256" "$patch_url"
    step "Installing the patch"
    tar -xjf "$download_dir/$patch_file" -C "$game_dir"

    step "Unpacking compressed maps (takes a minute)"
    local compressed_map
    for compressed_map in "$game_dir"/Maps/*.uz; do
        (cd "$system_dir" && ./ucc-bin decompress "../Maps/${compressed_map##*/}" -nohomedir >/dev/null)
        rm "$compressed_map"
    done
    find "$system_dir" "$HOME/.utpg/System" -maxdepth 1 -name '*.unr' -exec mv -t "$game_dir/Maps/" {} + 2>/dev/null || true
    touch "$game_dir/.base-installed"
}

install_family_pack() {
    if [[ -f "$game_dir/.pack-installed" ]]; then
        echo "Family mod pack already installed."
        return
    fi
    step "Downloading the family mod pack (maps, mods, skins, music)"
    local part_name part_sha256 parts=()
    while read -r part_sha256 part_name; do
        download_verified "$download_dir/$part_name" "$part_sha256" "$pack_release_url/$part_name"
        parts+=("$download_dir/$part_name")
    done < "$repo_dir/pack/SHA256SUMS"
    step "Installing the family mod pack"
    cat "${parts[@]}" | zstd -d -q | tar -xf - -C "$game_dir"
    touch "$game_dir/.pack-installed"
}

install_config() {
    step "Installing preconfigured settings"
    local file
    for file in "$repo_dir"/config/*.ini "$repo_dir"/config/mods/*.ini; do
        [[ -f "$system_dir/${file##*/}" ]] || cp "$file" "$system_dir/"
    done
    [[ -f "$system_dir/ServerUser.ini" ]] || cp "$repo_dir/config/User.ini" "$system_dir/ServerUser.ini"
}

detect_resolution() {
    local resolution=""
    if command -v hyprctl >/dev/null; then
        resolution=$(hyprctl monitors 2>/dev/null | grep -oE '^\s*[0-9]+x[0-9]+' | head -1 | tr -d '[:space:]')
    fi
    if [[ -z "$resolution" ]] && command -v xrandr >/dev/null; then
        resolution=$(xrandr --query 2>/dev/null | grep ' connected primary' | grep -oE '[0-9]+x[0-9]+' | head -1)
        [[ -n "$resolution" ]] || resolution=$(xrandr --query 2>/dev/null | grep -oE 'current [0-9]+ x [0-9]+' | head -1 | awk '{print $2"x"$4}')
    fi
    echo "${resolution:-1920x1080}"
}

set_ini_value() {
    local file="$1" section="$2" key="$3" value="$4"
    awk -v section="[$section]" -v key="$key" -v value="$value" '
        /^\[/ { inside = ($0 == section) }
        inside && index($0, key "=") == 1 { print key "=" value; next }
        { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

ask() {
    local prompt="$1" variable="$2"
    read -r -p "$prompt" "${variable?}" || fail "No answer given; run ./setup.sh again in a terminal."
}

ask_questions() {
    step "A few questions first (the rest runs on its own)"
    local detected
    detected=$(detect_resolution)
    while true; do
        ask "Screen resolution [$detected] (Enter to accept, or type e.g. 2560x1440): " screen_resolution
        screen_resolution="${screen_resolution:-$detected}"
        [[ "$screen_resolution" =~ ^[0-9]+x[0-9]+$ ]] && break
        echo "Please type it like 1920x1080."
    done

    while true; do
        ask "Player name (letters/numbers, no spaces): " player_name
        [[ "$player_name" =~ ^[A-Za-z0-9_.-]{1,20}$ ]] && break
        echo "Please use 1-20 letters, numbers, dots, dashes or underscores."
    done

    echo "Character:  1) Male Soldier  2) Female Soldier  3) Male Commando  4) Female Commando  5) Boss"
    while true; do
        ask "Pick 1-5 [1]: " character_choice
        character_choice="${character_choice:-1}"
        [[ "$character_choice" =~ ^[1-5]$ ]] && break
    done

    echo "Team color (used in team games):  1) Red  2) Blue  3) Green  4) Gold"
    while true; do
        ask "Pick 1-4 [1]: " team_choice
        team_choice="${team_choice:-1}"
        [[ "$team_choice" =~ ^[1-4]$ ]] && break
    done

    local current_address=""
    [[ -f "$repo_dir/.server-address" ]] && current_address=$(<"$repo_dir/.server-address")
    ask "Family server address to join, e.g. 203.0.113.5 (ask whoever hosts; Enter to ${current_address:+keep $current_address}${current_address:-skip}): " server_address
    server_address="${server_address:-$current_address}"
    if [[ -n "$server_address" && "$server_address" != *:* ]]; then
        server_address="$server_address:7777"
    fi
}

apply_answers() {
    step "Saving your settings"
    set_ini_value "$system_dir/UnrealTournament.ini" SDLDrv.SDLClient FullscreenViewportX "${screen_resolution%x*}"
    set_ini_value "$system_dir/UnrealTournament.ini" SDLDrv.SDLClient FullscreenViewportY "${screen_resolution#*x}"

    local class skin face voice
    case "$character_choice" in
        1) class=Botpack.TMale2;   skin=SoldierSkins.blkt;   face=SoldierSkins.Malcom;    voice=BotPack.VoiceMaleTwo ;;
        2) class=Botpack.TFemale2; skin=SGirlSkins.army;     face=SGirlSkins.Lauren;      voice=BotPack.VoiceFemaleTwo ;;
        3) class=Botpack.TMale1;   skin=CommandoSkins.cmdo;  face=CommandoSkins.Blake;    voice=BotPack.VoiceMaleOne ;;
        4) class=Botpack.TFemale1; skin=FCommandoSkins.cmdo; face=FCommandoSkins.Gromida; voice=BotPack.VoiceFemaleOne ;;
        5) class=Botpack.TBoss;    skin=BossSkins.boss;      face=BossSkins.Xan;          voice=BotPack.VoiceBoss ;;
    esac
    local user_ini="$system_dir/User.ini"
    set_ini_value "$user_ini" DefaultPlayer Name "$player_name"
    set_ini_value "$user_ini" DefaultPlayer Class "$class"
    set_ini_value "$user_ini" DefaultPlayer skin "$skin"
    set_ini_value "$user_ini" DefaultPlayer Face "$face"
    set_ini_value "$user_ini" DefaultPlayer Voice "$voice"
    set_ini_value "$user_ini" DefaultPlayer team "$((team_choice - 1))"
    echo "Profile saved. Fine-tune your look in the game under Options > Player Setup."

    if [[ -n "$server_address" ]]; then
        echo "$server_address" > "$repo_dir/.server-address"
        echo "Server address saved. Run ./join.sh to connect."
    fi
}

mkdir -p "$download_dir"
ask_questions
install_dependencies < /dev/null
install_base_game < /dev/null
install_family_pack < /dev/null
install_config
apply_answers

step "All done!"
echo "Play:            ./play.sh"
echo "Join the server: ./join.sh"
echo "Host the server: ./server.sh   (stops when you close that terminal)"
echo "You can delete the 'downloads' folder to free ~1.6 GB."
