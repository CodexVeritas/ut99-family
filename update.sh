#!/usr/bin/env bash
# Gets the latest scripts, shared settings, and mod pack from GitHub. Your profile and key bindings are kept.
set -euo pipefail
cd "$(dirname "$0")"
git pull --ff-only
exec ./setup.sh --update
