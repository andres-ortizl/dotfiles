#!/bin/sh
set -eu
cd "$(dirname "$0")"

# Dummy values let the openbao service start before .env exists (compose
# interpolates the whole file even for a single service).
if [ -s .env ]; then
  docker compose up -d openbao
else
  PIHOLE_PASSWORD=bootstrap DB_PASSWORD=bootstrap docker compose up -d openbao
fi
./vault-unseal.sh

docker exec -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN="$(cat ./data/openbao-auth/token)" openbao \
  bao kv get -field=dotenv secret/homeserver > .env.tmp
chmod 600 .env.tmp
mv .env.tmp .env

docker compose up -d "$@"
rm -f .env
./vault-unseal.sh
