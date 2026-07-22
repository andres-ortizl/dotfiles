#!/bin/sh
# One-time OpenBao setup: init, unseal, load current .env, create the single
# fixed userpass login for the web UI. Usage: ./vault-init.sh <ui-password>
set -eu
cd "$(dirname "$0")"

[ $# -eq 1 ] || { echo "usage: $0 <ui-password>" >&2; exit 1; }
[ -s .env ] || { echo ".env is missing or empty; recover it first (vault is seeded from it)" >&2; exit 1; }

bao() {
  docker exec -i -e BAO_ADDR=http://127.0.0.1:8200 ${BAO_TOKEN:+-e BAO_TOKEN=$BAO_TOKEN} openbao bao "$@"
}

mkdir -p data/openbao-auth
docker compose up -d openbao
sleep 3

INIT=$(bao operator init -key-shares=1 -key-threshold=1)
UNSEAL_KEY=$(printf '%s\n' "$INIT" | awk -F': ' '/Unseal Key 1/{print $2}')
ROOT_TOKEN=$(printf '%s\n' "$INIT" | awk -F': ' '/Initial Root Token/{print $2}')
[ -n "$UNSEAL_KEY" ] && [ -n "$ROOT_TOKEN" ] || { echo "init parse failed:"; printf '%s\n' "$INIT"; exit 1; } >&2

printf '%s\n' "$UNSEAL_KEY" > data/openbao-auth/unseal-key
printf '%s\n' "$ROOT_TOKEN" > data/openbao-auth/token
chmod 600 data/openbao-auth/unseal-key data/openbao-auth/token

./vault-unseal.sh
BAO_TOKEN=$ROOT_TOKEN

bao secrets enable -path=secret -version=2 kv
bao kv put secret/homeserver dotenv="$(cat .env)"

bao auth enable userpass
bao policy write homeserver - <<'EOF'
path "secret/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
bao write auth/userpass/users/andrew password="$1" token_policies=homeserver

echo
echo "Done. Web UI: http://vault.<domain> (method Username, andrew / <your password>)."
echo "SAVE IN BITWARDEN (disaster recovery):"
echo "  unseal key: $UNSEAL_KEY"
echo "  root token: $ROOT_TOKEN"
