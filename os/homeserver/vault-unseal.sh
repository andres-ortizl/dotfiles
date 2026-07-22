#!/bin/sh
set -eu
cd "$(dirname "$0")"
KEY_FILE=./data/openbao-auth/unseal-key
[ -f "$KEY_FILE" ] || { echo "missing $KEY_FILE (run vault-init.sh first)" >&2; exit 1; }
for i in $(seq 1 30); do
  if docker exec -e BAO_ADDR=http://127.0.0.1:8200 openbao \
    bao operator unseal "$(cat "$KEY_FILE")" >/dev/null 2>&1; then
    exit 0
  fi
  sleep 1
done
echo "could not unseal openbao after 30s" >&2
exit 1
