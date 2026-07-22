#!/bin/sh
set -eu
cd "$(dirname "$0")"
[ -s .env ] || { echo ".env missing or empty; run ./recover-env.sh or restore it from the Bitwarden note" >&2; exit 1; }
docker compose up -d "$@"
