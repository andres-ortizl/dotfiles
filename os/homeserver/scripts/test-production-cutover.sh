#!/bin/sh
set -eu
umask 077

scripts_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
homeserver_dir=$(dirname "$scripts_dir")
compose="$homeserver_dir/docker-compose.yml"
glance="$homeserver_dir/config/glance/glance.yml"
evidence=${TASK6_EVIDENCE:-}
root=$(mktemp -d "${TMPDIR:-/tmp}/n33lab-cutover.XXXXXX")
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

grep -Fq 'ACME_STORAGE:-/letsencrypt/acme.json' "$compose" || fail 'production ACME storage default is missing'
grep -Fq 'ACME_CA_SERVER:-https://acme-v02.api.letsencrypt.org/directory' "$compose" || fail 'production ACME CA default is missing'
grep -Fq 'ACME_CA_SERVER=https://acme-v02.api.letsencrypt.org/directory' "$homeserver_dir/.env.example" || fail 'production CA template is missing'
grep -Fq 'ACME_STORAGE=/letsencrypt/acme.json' "$homeserver_dir/.env.example" || fail 'production storage template is missing'
if grep -Eq '"(9090:8080|3333:80)"|api\.insecure' "$compose"; then
  fail 'retired direct port or insecure API remains'
fi

for service in immich qbittorrent files chat excalidraw pihole traefik docker logs uptime backup ha ha-esphome ha-music ha-flows; do
  grep -Fq "url: https://$service.\${DOMAIN}" "$glance" || fail "Glance user URL is not HTTPS: $service"
done
grep -Fq "url: https://traefik.\${DOMAIN}/dashboard/" "$glance" || fail 'Traefik user URL is not canonical'
grep -Fq 'url: https://192.168.1.33:9443/desktop/?os=ugospro#/' "$glance" || fail 'UGREEN user URL is not canonical'
grep -Fq 'check-url: http://host.docker.internal:9999' "$glance" || fail 'UGREEN server-side check URL is missing'
grep -Fq 'alt-status-codes: [307]' "$glance" || fail 'UGREEN redirect status acceptance is missing'
grep -Fq -- '--ping=true' "$compose" || fail 'Traefik ping is disabled'
grep -Fq -- '--ping.entrypoint=ping' "$compose" || fail 'Traefik ping entrypoint is missing'
grep -Fq -- '--entrypoints.ping.address=:8082' "$compose" || fail 'Traefik ping entrypoint address is missing'
if grep -Eq '(^|[" ])([0-9.]+:)?8082:|(^|[" ])8082:[0-9]+' "$compose"; then
  fail 'Traefik ping entrypoint is externally published'
fi
grep -Fq 'check-url: http://traefik:8082/ping' "$glance" || fail 'Glance Traefik check URL is missing'
grep -Fq 'url: http://immich-server:2283' "$glance" || fail 'internal Glance checks changed unexpectedly'
grep -Fq 'url: http://host.docker.internal:8123' "$glance" || fail 'internal host check changed unexpectedly'
grep -Fq 'FORGEJO__server__ROOT_URL=https://git.' "$compose" || fail 'Forgejo canonical URL is not HTTPS'
grep -Fq "service: api@internal" "$homeserver_dir/config/traefik/dynamic/services.yml" || fail 'Traefik dashboard backend is not api@internal'
grep -Fq 'middlewares: [authelia]' "$homeserver_dir/config/traefik/dynamic/services.yml" || fail 'Traefik dashboard authentication is missing'

mkdir -p "$root/bin" "$root/secrets" "$root/data/traefik/letsencrypt"
cat >"$root/bin/git" <<'EOF'
#!/bin/sh
case "$1" in
  -C) [ "$3" = rev-parse ] && printf '%s\n' "$2"/.. ;;
  status) : ;;
  *) : ;;
esac
EOF
cat >"$root/bin/docker" <<'EOF'
#!/bin/sh
env_file=
for argument do
  [ "$argument" = --env-file ] && next=1 && continue
  if [ "${next-}" = 1 ]; then env_file=$argument; next=0; fi
done
[ -z "$env_file" ] || [ "$(stat -c '%a' "$env_file")" = 600 ] || exit 1
exit 0
EOF
cat >"$root/bin/timeout" <<'EOF'
#!/bin/sh
shift
exec "$@"
EOF
chmod 755 "$root/bin/git" "$root/bin/docker" "$root/bin/timeout"

cp "$compose" "$root/docker-compose.yml"
cp "$homeserver_dir/deploy.sh" "$root/deploy.sh"
mkdir -p "$root/config" "$root/config/traefik/dynamic"
cp -R "$homeserver_dir/config/traefik/dynamic/." "$root/config/traefik/dynamic/"
for file in cloudflare_dns_api_token authelia-jwt authelia-session authelia-storage-encryption authelia-users immich-server.env immich-ml.env esphome.env mqtt-passwd mqtt-acl; do
  : >"$root/secrets/$file"
  chmod 600 "$root/secrets/$file"
done
printf '%s\n' fixture >"$root/secrets/cloudflare_dns_api_token"
printf '%s\n' 'DB_USERNAME=postgres' 'DB_PASSWORD=fixture' 'DB_DATABASE_NAME=immich' >"$root/secrets/immich-server.env"
printf '%s\n' 'ESPHOME_USERNAME=fixture' 'ESPHOME_PASSWORD=fixture' 'ESPHOME_TRUSTED_DOMAINS=example.test' >"$root/secrets/esphome.env"
printf '%s\n' "fixture:\$2b\$12\$01234567890123456789012345678901234567890123456789012" >"$root/secrets/mqtt-passwd"
printf '%s\n' 'user fixture' 'topic readwrite home/fixture' >"$root/secrets/mqtt-acl"
printf '%s\n' fixture >"$root/secrets/authelia-jwt"
printf '%s\n' fixture >"$root/secrets/authelia-session"
printf '%s\n' fixture >"$root/secrets/authelia-storage-encryption"
printf '%s\n' 'users:' >"$root/secrets/authelia-users"

cat >"$root/.env" <<'EOF'
DOMAIN=n33lab.com
ACME_EMAIL=admin@example.test
ACME_CA_SERVER=https://acme-v02.api.letsencrypt.org/directory
ACME_STORAGE=/letsencrypt/acme.json
DB_PASSWORD=fixture
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
PIHOLE_PASSWORD=fixture
EOF
chmod 600 "$root/.env"
PATH="$root/bin:$PATH" HOME="$root" /bin/sh "$root/deploy.sh" --check >/dev/null || fail 'fake mode-600 Compose preflight failed'
rm "$root/secrets/mqtt-passwd"
expect_fail env PATH="$root/bin:$PATH" HOME="$root" /bin/sh "$root/deploy.sh" --check
printf '%s\n' "fixture:\$2b\$12\$01234567890123456789012345678901234567890123456789012" >"$root/secrets/mqtt-passwd"
chmod 644 "$root/secrets/mqtt-passwd"
expect_fail env PATH="$root/bin:$PATH" HOME="$root" /bin/sh "$root/deploy.sh" --check
chmod 600 "$root/secrets/mqtt-passwd"
printf '%s\n' 'invalid' >"$root/secrets/mqtt-acl"
expect_fail env PATH="$root/bin:$PATH" HOME="$root" /bin/sh "$root/deploy.sh" --check
printf '%s\n' 'user fixture' 'topic readwrite home/fixture' >"$root/secrets/mqtt-acl"
chmod 600 "$root/secrets/mqtt-acl"

sed 's#ACME_CA_SERVER=https://acme-v02.api.letsencrypt.org/directory#ACME_CA_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory#; s#ACME_STORAGE=/letsencrypt/acme.json#ACME_STORAGE=/letsencrypt/acme-staging.json#' "$root/.env" >"$root/staging.env"
chmod 600 "$root/staging.env"
cp "$root/staging.env" "$root/.env"
PATH="$root/bin:$PATH" HOME="$root" /bin/sh "$root/deploy.sh" --check >/dev/null || fail 'explicit staging override failed'
sed 's#ACME_CA_SERVER=https://acme-staging-v02.api.letsencrypt.org/directory#ACME_CA_SERVER=https://acme-v02.api.letsencrypt.org/directory#; s#ACME_STORAGE=/letsencrypt/acme-staging.json#ACME_STORAGE=/letsencrypt/acme.json#' "$root/staging.env" >"$root/production.env"
cp "$root/production.env" "$root/.env"

sed 's#ACME_CA_SERVER=.*#ACME_CA_SERVER=https://example.test/ca#' "$root/production.env" >"$root/bad.env"
chmod 600 "$root/bad.env"
mv "$root/bad.env" "$root/.env"
expect_fail env PATH="$root/bin:$PATH" HOME="$root" /bin/sh "$root/deploy.sh" --check
sed 's#ACME_STORAGE=/letsencrypt/acme.json#ACME_STORAGE=/tmp/acme.json#' "$root/production.env" >"$root/bad.env"
chmod 600 "$root/bad.env"
mv "$root/bad.env" "$root/.env"
expect_fail env PATH="$root/bin:$PATH" HOME="$root" /bin/sh "$root/deploy.sh" --check

if [ -n "$evidence" ]; then
  evidence_dir=$(dirname "$evidence")
  [ -d "$evidence_dir" ] || fail 'evidence directory is missing'
  temporary="$evidence_dir/.task6.XXXXXX"
  temporary=$(mktemp "$temporary")
  printf '%s\n' 'check_identifier=task-6-production-cutover' 'execution_node=workstation' \
    'status=PASS' 'file_mode=600' 'test_exit_code=0' >"$temporary"
  chmod 600 "$temporary"
  mv "$temporary" "$evidence"
fi

printf '%s\n' 'production_cutover_status=PASS'
