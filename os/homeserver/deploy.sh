#!/bin/sh
set -eu
cd "$(dirname "$0")"
sops -d --input-type dotenv --output-type dotenv .env.sops > .env
chmod 600 .env
docker compose up -d "$@"
