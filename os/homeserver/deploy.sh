#!/bin/sh
set -eu
cd "$(dirname "$0")"

sops_run() {
  if command -v sops >/dev/null 2>&1; then
    sops "$@"
  else
    docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/work" -w /work \
      -v "$HOME/.config/sops/age/keys.txt:/keys.txt:ro" -e SOPS_AGE_KEY_FILE=/keys.txt \
      ghcr.io/getsops/sops:v3.13.2 "$@"
  fi
}

sops_run -d --input-type dotenv --output-type dotenv .env.sops > .env
chmod 600 .env
docker compose up -d "$@"
