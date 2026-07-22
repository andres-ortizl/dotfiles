#!/bin/sh
# One-off: rebuild .env from the env baked into the running immich_server
# container (it loads the whole .env via env_file). Safe to delete after use.
set -eu
cd "$(dirname "$0")"

if [ -s .env ]; then
  echo ".env already exists and is non-empty; refusing to overwrite" >&2
  exit 1
fi

docker inspect immich_server --format '{{range .Config.Env}}{{println .}}{{end}}' \
  | grep -E '^(DOMAIN|PUID|PGID|TZ|DATA_ROOT|UPLOAD_LOCATION|DB_PASSWORD|DB_USERNAME|DB_DATABASE_NAME|IMMICH_VERSION|PIHOLE_PASSWORD|PIHOLE_DNS|PIHOLE_API_KEY|TS_AUTHKEY)=' > .env
chmod 600 .env

N=$(grep -c = .env)
echo "recovered $N variables into .env:"
cut -d= -f1 .env
