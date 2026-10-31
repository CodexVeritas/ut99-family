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

configure_screen() {
    step "Screen setup"
    local detected answer
    detected=$(detect_resolution)
    read -r -p "Your screen resolution looks like $detected. Press Enter to accept or type another (e.g. 2560x1440): " answer
    answer="${answer:-$detected}"
    [[ "$answer" =~ ^[0-9]+x[0-9]+$ ]] || fail "Resolution must look like 1920x1080"
    set_ini_value "$system_dir/UnrealTournament.ini" SDLDrv.SDLClient FullscreenViewportX "${answer%x*}"
    set_ini_value "$system_dir/UnrealTournament.ini" SDLDrv.SDLClient FullscreenViewportY "${answer#*x}"
}

configure_profile() {
    step "Your player profile"
    local name model_choice team_choice
    while true; do
        read -r -p "Player name (letters/numbers, no spaces): " name
        [[ "$name" =~ ^[A-Za-z0-9_.-]{1,20}$ ]] && break
        echo "Please use 1-20 letters, numbers, dots, dashes or underscores."
    done
    echo "Character:  1) Male Soldier  2) Female Soldier  3) Male Commando  4) Female Commando  5) Boss"
    read -r -p "Pick 1-5 [1]: " model_choice
    local class skin face
    case "${model_choice:-1}" in
        1) class=Botpack.TMale2;  skin=SoldierSkins.blkt;   face=SoldierSkins.Malcom ;;
        2) class=Botpack.TFemale2; skin=SGirlSkins.army;    face=SGirlSkins.Lauren ;;
        3) class=Botpack.TMale1;  skin=CommandoSkins.cmdo;  face=CommandoSkins.Blake ;;
        4) class=Botpack.TFemale1; skin=FCommandoSkins.cmdo; face=FCommandoSkins.Gromida ;;
        5) class=Botpack.TBoss;   skin=BossSkins.boss;      face=BossSkins.Xan ;;
        *) fail "Please pick a number from 1 to 5" ;;
    esac
    echo "Team color (used in team games):  1) Red  2) Blue  3) Green  4) Gold"
    read -r -p "Pick 1-4 [1]: " team_choice
    [[ "${team_choice:-1}" =~ ^[1-4]$ ]] || fail "Please pick a number from 1 to 4"

    local user_ini="$system_dir/User.ini"
    set_ini_value "$user_ini" DefaultPlayer Name "$name"
    set_ini_value "$user_ini" DefaultPlayer Class "$class"
    set_ini_value "$user_ini" DefaultPlayer skin "$skin"
    set_ini_value "$user_ini" DefaultPlayer Face "$face"
    set_ini_value "$user_ini" DefaultPlayer team "$(( ${team_choice:-1} - 1 ))"
    echo "Saved. You can fine-tune your look in the game under Options > Player Setup."
}

configure_server_address() {
    step "Family server"
    local current="" address
    [[ -f "$repo_dir/.server-address" ]] && current=$(<"$repo_dir/.server-address")
    read -r -p "Address of the family server to join, e.g. 203.0.113.5 (ask whoever hosts; Enter to ${current:+keep $current}${current:-skip}): " address
    address="${address:-$current}"
    if [[ -n "$address" ]]; then
        [[ "$address" == *:* ]] || address="$address:7777"
        echo "$address" > "$repo_dir/.server-address"
        echo "Saved. Run ./join.sh to connect."
    fi
}

mkdir -p "$download_dir"
install_dependencies
install_base_game
install_family_pack
install_config
configure_screen
configure_profile
configure_server_address

step "All done!"
echo "Play:            ./play.sh"
echo "Join the server: ./join.sh"
echo "Host the server: ./server.sh   (stops when you close that terminal)"
echo "You can delete the 'downloads' folder to free ~1.6 GB."
