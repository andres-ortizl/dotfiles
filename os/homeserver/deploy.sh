#!/bin/sh
set -eu

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s [--check] [service ...]\n' "$0" >&2
  exit 2
}

file_value() {
  awk -F= -v wanted="$2" '$1 == wanted { count++; value = substr($0, index($0, "=") + 1) } END { if (count != 1) exit 1; print value }' "$1"
}

validate_env_names() {
  awk -F= -v allowed="$2" -v required="$3" '
    BEGIN {
      split(allowed, allowed_names, " ")
      for (item in allowed_names) allowed_name[allowed_names[item]] = 1
      split(required, required_names, " ")
      for (item in required_names) required_name[required_names[item]] = 1
    }
    /^[[:space:]]*($|#)/ { next }
    {
      key = $1
      if (key !~ /^[A-Z][A-Z0-9_]*$/ || !allowed_name[key] || seen[key]++ || NF < 2) exit 1
      value = substr($0, index($0, "=") + 1)
      if (required_name[key] && value == "") exit 1
    }
    END {
      for (key in required_name) if (!seen[key]) exit 1
    }
  ' "$1"
}

check_private_file() {
  [ -f "$1" ] && [ ! -L "$1" ] || fail "required runtime file is missing"
  [ "$(stat -c '%a' "$1")" = 600 ] || fail "runtime file permissions must be 600"
  [ "$(stat -c '%u' "$1")" = "$(id -u)" ] || fail "runtime file owner must match the deployment user"
}

run_bounded() {
  command -v timeout >/dev/null 2>&1 || {
    printf '%s\n' "timeout is required for bounded external commands" >&2
    return 127
  }
  timeout 60 "$@"
}

check_only=false
if [ "${1-}" = "--check" ]; then
  check_only=true
  shift
elif [ "${1-}" != "" ] && [ "${1#--}" != "$1" ]; then
  usage
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null) || fail "unable to locate repository root"
cd "$repo_root"

[ -z "$(git status --porcelain --untracked-files=no)" ] || fail "tracked repository changes block deployment"

homeserver_env="$script_dir/.env"
immich_server_env="$script_dir/secrets/immich-server.env"
immich_ml_env="$script_dir/secrets/immich-ml.env"
esphome_env="$script_dir/secrets/esphome.env"
cloudflare_dns_api_token="$script_dir/secrets/cloudflare_dns_api_token"
authelia_jwt="$script_dir/secrets/authelia-jwt"
authelia_session="$script_dir/secrets/authelia-session"
authelia_storage_encryption="$script_dir/secrets/authelia-storage-encryption"
authelia_users="$script_dir/secrets/authelia-users"
mqtt_passwd="$script_dir/secrets/mqtt-passwd"
mqtt_acl="$script_dir/secrets/mqtt-acl"

[ -s "$homeserver_env" ] || fail ".env is missing or empty; run ./recover-env.sh"
check_private_file "$homeserver_env"
check_private_file "$immich_server_env"
check_private_file "$immich_ml_env"
check_private_file "$esphome_env"
check_private_file "$cloudflare_dns_api_token"
check_private_file "$authelia_jwt"
check_private_file "$authelia_session"
check_private_file "$authelia_storage_encryption"
check_private_file "$authelia_users"
check_private_file "$mqtt_passwd"
check_private_file "$mqtt_acl"

acme_email=$(file_value "$homeserver_env" ACME_EMAIL 2>/dev/null || true)
acme_ca_server=$(file_value "$homeserver_env" ACME_CA_SERVER 2>/dev/null || true)
acme_storage=$(file_value "$homeserver_env" ACME_STORAGE 2>/dev/null || true)
[ -n "$acme_email" ] || fail "ACME_EMAIL is required"
printf '%s\n' "$acme_email" | grep -Eq "^[A-Za-z0-9.!#\$%&'*+/=?^_\`{|}~-]+@[A-Za-z0-9.-]+$" \
  || fail "ACME_EMAIL has an unsafe value"
if [ -n "$acme_ca_server" ]; then
  printf '%s\n' "$acme_ca_server" | grep -Eq '^https://acme-(staging-)?v02\.api\.letsencrypt\.org/directory$' \
    || fail "ACME_CA_SERVER has an unsafe value"
fi
if [ -n "$acme_storage" ]; then
  printf '%s\n' "$acme_storage" | grep -Eq '^/letsencrypt/[A-Za-z0-9._-]+\.json$' \
    || fail "ACME_STORAGE has an unsafe value"
fi
awk 'NF != 1 || /[[:space:]=]/ { exit 1 } END { if (NR != 1) exit 1 }' "$cloudflare_dns_api_token" \
  || fail "Cloudflare DNS API token has an invalid format"
awk 'BEGIN { valid = 0 } /^[[:space:]]*($|#)/ { next } /^[A-Za-z0-9._-]+:\$[^[:space:]]+$/ { valid++; next } { exit 1 } END { if (!valid) exit 1 }' "$mqtt_passwd" \
  || fail "mqtt-passwd has an invalid schema"
awk '
  /^[[:space:]]*($|#)/ { next }
  /^user [A-Za-z0-9._-]+$/ { users++; next }
  /^topic (read|write|readwrite) [^[:space:]#+]+$/ { topics++; next }
  { exit 1 }
  END { if (!users || !topics) exit 1 }
' "$mqtt_acl" || fail "mqtt-acl has an invalid schema"

[ "$(file_value "$homeserver_env" DOMAIN 2>/dev/null || true)" = n33lab.com ] || fail "DOMAIN must appear exactly once and equal n33lab.com"
validate_env_names "$immich_server_env" \
  "DB_USERNAME DB_PASSWORD DB_DATABASE_NAME" \
  "DB_USERNAME DB_PASSWORD DB_DATABASE_NAME" || fail "immich-server.env has an invalid schema"
validate_env_names "$immich_ml_env" \
  "TZ IMMICH_ENV IMMICH_LOG_LEVEL NO_COLOR IMMICH_HOST IMMICH_PORT MACHINE_LEARNING_MODEL_TTL MACHINE_LEARNING_MODEL_TTL_POLL_S MACHINE_LEARNING_CACHE_FOLDER MACHINE_LEARNING_REQUEST_THREADS MACHINE_LEARNING_MODEL_INTER_OP_THREADS MACHINE_LEARNING_MODEL_INTRA_OP_THREADS MACHINE_LEARNING_WORKERS MACHINE_LEARNING_DEVICE_IDS" \
  "" || fail "immich-ml.env has an invalid schema"
validate_env_names "$esphome_env" \
  "ESPHOME_USERNAME ESPHOME_PASSWORD ESPHOME_TRUSTED_DOMAINS" \
  "ESPHOME_USERNAME ESPHOME_PASSWORD ESPHOME_TRUSTED_DOMAINS" || fail "esphome.env has an invalid schema"
[ -s "$authelia_jwt" ] || fail "authelia-jwt is empty"
[ -s "$authelia_session" ] || fail "authelia-session is empty"
[ -s "$authelia_storage_encryption" ] || fail "authelia-storage-encryption is empty"
[ -s "$authelia_users" ] || fail "authelia-users is empty"

for key in DB_USERNAME DB_PASSWORD DB_DATABASE_NAME; do
  [ "$(file_value "$homeserver_env" "$key" 2>/dev/null || true)" = "$(file_value "$immich_server_env" "$key" 2>/dev/null || true)" ] \
    || fail "Immich database settings do not match the Compose interpolation file"
done

compose() {
  run_bounded docker compose --project-directory "$script_dir" --env-file "$homeserver_env" -f "$script_dir/docker-compose.yml" "$@"
}

compose config --quiet || fail "Compose configuration validation failed"

if [ "$check_only" = true ]; then
  printf '%s\n' "deployment preflight passed"
  exit 0
fi

compose up -d "$@"
