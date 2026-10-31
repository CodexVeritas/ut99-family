#!/usr/bin/env bash
# Starts Unreal Tournament and connects straight to the family server saved by setup.sh.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")" && pwd)"
if [[ ! -s "$repo_dir/.server-address" ]]; then
    echo "No server address saved yet: run ./setup.sh and enter it when asked." >&2
    exit 1
fi
exec "$repo_dir/play.sh" "$(<"$repo_dir/.server-address")"
