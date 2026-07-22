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

if [ ! -f .env.sops ]; then
  [ -s .env ] || { echo "no .env.sops, and .env is missing or empty; refusing to bootstrap" >&2; exit 1; }
  echo "bootstrapping: encrypting .env -> .env.sops"
  sops_run -e --input-type dotenv --output-type dotenv .env > .env.sops.tmp
  grep -q '^sops_' .env.sops.tmp || { echo "encryption produced no sops metadata; aborting" >&2; rm -f .env.sops.tmp; exit 1; }
  mv .env.sops.tmp .env.sops
  git add .env.sops && git commit -m "homeserver: encrypted env" && git push
fi

sops_run -d --input-type dotenv --output-type dotenv .env.sops > .env.tmp
chmod 600 .env.tmp
mv .env.tmp .env
docker compose up -d "$@"
