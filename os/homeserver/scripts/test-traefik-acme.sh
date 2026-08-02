#!/bin/sh
set -eu
umask 077

scripts_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
homeserver_dir=$(dirname "$scripts_dir")
compose="$homeserver_dir/docker-compose.yml"
env_example="$homeserver_dir/.env.example"
root=$(mktemp -d "${TMPDIR:-/tmp}/n33lab-acme.XXXXXX")
trap 'rm -rf "$root"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_fail() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $*"
  fi
}

check_secret() {
  [ -f "$1" ] && [ ! -L "$1" ] && [ "$(stat -c '%a' "$1")" = 600 ] && [ "$(stat -c '%u' "$1")" = "$(id -u)" ]
}

check_single_resolver_owner() {
  [ "$(grep -Ec 'tls\.certresolver=cloudflare' "$1")" -eq 1 ]
}

validate_acme_input() {
  input=$1
  email=$(awk -F= '$1 == "ACME_EMAIL" { count++; value = substr($0, index($0, "=") + 1) } END { if (count != 1) exit 1; print value }' "$input") || return 1
  ca=$(awk -F= '$1 == "ACME_CA_SERVER" { count++; value = substr($0, index($0, "=") + 1) } END { if (count > 1) exit 1; print value }' "$input") || return 1
  storage=$(awk -F= '$1 == "ACME_STORAGE" { count++; value = substr($0, index($0, "=") + 1) } END { if (count > 1) exit 1; print value }' "$input") || return 1
  printf '%s\n' "$email" | grep -Eq "^[A-Za-z0-9.!#\$%&'*+/=?^_\`{|}~-]+@[A-Za-z0-9.-]+$" || return 1
  [ -z "$ca" ] || printf '%s\n' "$ca" | grep -Eq '^https://acme-(staging-)?v02\.api\.letsencrypt\.org/directory$' || return 1
  [ -z "$storage" ] || printf '%s\n' "$storage" | grep -Eq '^/letsencrypt/[A-Za-z0-9._-]+\.json$' || return 1
}

grep -Fq 'cloudflare_dns_api_token:' "$compose" || fail 'Compose secret is missing'
grep -Fq 'file: ./secrets/cloudflare_dns_api_token' "$compose" || fail 'Compose secret source is wrong'
grep -Fq 'CF_DNS_API_TOKEN_FILE=/run/secrets/cloudflare_dns_api_token' "$compose" || fail 'Traefik token file environment is missing'
grep -Fq './data/traefik/letsencrypt:/letsencrypt' "$compose" || fail 'ACME storage is not persistent'
grep -Fq 'ACME_STORAGE:-/letsencrypt/acme-staging.json' "$compose" || fail 'staging storage default is missing'
grep -Fq 'ACME_CA_SERVER:-https://acme-staging-v02.api.letsencrypt.org/directory' "$compose" || fail 'staging CA default is missing'
grep -Fq 'dnschallenge.provider=cloudflare' "$compose" || fail 'Cloudflare DNS challenge is missing'
grep -Fq 'dnschallenge.resolvers=1.1.1.1:53,1.0.0.1:53' "$compose" || fail 'explicit DNS resolvers are missing'

resolver_count=$(grep -Ec 'tls\.certresolver=cloudflare' "$compose")
[ "$resolver_count" -eq 1 ] || fail 'ACME resolver is not owned by exactly one router'
secret_service_count=$(awk '/^  [A-Za-z0-9_-]+:$/ { service=$1 } /    secrets:$/ { print service }' "$compose" | grep -Ec '^traefik:$')
[ "$secret_service_count" -eq 1 ] || fail 'Cloudflare secret is mounted outside Traefik'
apex_main="traefik.http.routers.glance-secure.tls.domains[0].main=\${DOMAIN:?set DOMAIN=n33lab.com}"
apex_san="traefik.http.routers.glance-secure.tls.domains[0].sans=*.\${DOMAIN:?set DOMAIN=n33lab.com}"
grep -Fq "$apex_main" "$compose" \
  || fail 'apex ACME main domain is missing'
grep -Fq "$apex_san" "$compose" \
  || fail 'wildcard ACME SAN is missing'
if grep -Eq 'routers\.(dashboard|dockhand|pihole|qbittorrent|immich|openwebui|excalidraw|gatus|dozzle|filebrowser|backrest|node-red|forgejo)-secure\..*certresolver=' "$compose"; then
  fail 'non-apex router owns an ACME resolver'
fi

grep -Fq 'ACME_EMAIL=' "$env_example" || fail 'ACME_EMAIL is undocumented'
grep -Fq 'ACME_CA_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory' "$env_example" \
  || fail 'staging CA is not documented'
grep -Fq 'ACME_STORAGE=/letsencrypt/acme-staging.json' "$env_example" || fail 'staging storage is not documented'
if grep -Eq 'CF_DNS_API_TOKEN=|cloudflare_dns_api_token=[^[:space:]#]' "$compose" "$env_example"; then
  fail 'Cloudflare token value is injected into tracked configuration'
fi

mkdir -p "$root/secrets" "$root/config/traefik/dynamic" "$root/config/glance" "$root/data/traefik/letsencrypt"
printf '%s\n' 'fixture-token-not-real' >"$root/secrets/cloudflare_dns_api_token"
chmod 600 "$root/secrets/cloudflare_dns_api_token"
touch "$root/secrets/immich-server.env" "$root/secrets/immich-ml.env" "$root/secrets/gatus.env"
cp "$compose" "$root/docker-compose.yml"
cat >"$root/.env" <<'EOF'
DOMAIN=example.test
ACME_EMAIL=admin@example.test
ACME_CA_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory
ACME_STORAGE=/letsencrypt/acme-staging.json
DB_PASSWORD=fixture
PIHOLE_PASSWORD=fixture
EOF

compose_config() {
  docker compose --project-directory "$root" --env-file "$root/.env" -f "$root/docker-compose.yml" config --quiet
}

compose_config >/dev/null 2>&1 || fail 'Compose staging fixture does not validate'
grep -Fq 'secrets:' "$compose" || fail 'secret section disappeared'
if grep -Eq 'CF_DNS_API_TOKEN_FILE|cloudflare_dns_api_token' "$root/.env"; then
  fail 'token wiring leaked into the shared env fixture'
fi

sed 's#secrets/cloudflare_dns_api_token#secrets/missing-token#' "$compose" >"$root/missing-compose.yml"
expect_fail check_secret "$root/secrets/missing-token"
rm -f "$root/secrets/cloudflare_dns_api_token"
expect_fail check_secret "$root/secrets/cloudflare_dns_api_token"
printf '%s\n' 'fixture-token-not-real' >"$root/secrets/cloudflare_dns_api_token"
chmod 600 "$root/secrets/cloudflare_dns_api_token"

sed 's#ACME_EMAIL=admin@example.test#ACME_EMAIL=bad email#' "$root/.env" >"$root/bad-email.env"
if grep -Eq '^ACME_EMAIL=[^@[:space:]]+[[:space:]]' "$root/bad-email.env"; then
  :
else
  fail 'malformed email fixture was not created'
fi
expect_fail validate_acme_input "$root/bad-email.env"
sed 's#ACME_CA_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory#ACME_CA_SERVER=https://example.test/ca#' "$root/.env" >"$root/bad-ca.env"
grep -Fq 'ACME_CA_SERVER=https://example.test/ca' "$root/bad-ca.env" || fail 'malformed CA fixture was not created'
expect_fail validate_acme_input "$root/bad-ca.env"
sed 's#ACME_STORAGE=/letsencrypt/acme-staging.json#ACME_STORAGE=/tmp/acme.json#' "$root/.env" >"$root/bad-storage.env"
grep -Fq 'ACME_STORAGE=/tmp/acme.json' "$root/bad-storage.env" || fail 'malformed storage fixture was not created'
expect_fail validate_acme_input "$root/bad-storage.env"

cat >"$root/production.env" <<'EOF'
DOMAIN=example.test
ACME_EMAIL=admin@example.test
ACME_CA_SERVER=https://acme-v02.api.letsencrypt.org/directory
ACME_STORAGE=/letsencrypt/acme-production.json
DB_PASSWORD=fixture
PIHOLE_PASSWORD=fixture
EOF
docker compose --project-directory "$root" --env-file "$root/production.env" -f "$root/docker-compose.yml" config --quiet >/dev/null 2>&1 \
  || fail 'production switch fixture does not validate'

sed 's/tls\.certresolver=cloudflare/tls.certresolver=cloudflare\n      - "traefik.http.routers.dashboard-secure.tls.certresolver=cloudflare"/' "$compose" >"$root/duplicate-compose.yml"
[ "$(grep -Ec 'tls\.certresolver=cloudflare' "$root/duplicate-compose.yml")" -eq 2 ] || fail 'duplicate resolver fixture was not created'
expect_fail check_single_resolver_owner "$root/duplicate-compose.yml"

[ "$(stat -c '%a' "$root/secrets/cloudflare_dns_api_token")" = 600 ] || fail 'fixture secret is not mode 600'
[ "$(stat -c '%u' "$root/secrets/cloudflare_dns_api_token")" = "$(id -u)" ] || fail 'fixture secret owner is incorrect'

printf '%s\n' 'traefik_acme_status=PASS'
