#!/bin/sh
set -eu
umask 077

scripts_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
homeserver_dir=$(dirname "$scripts_dir")
compose="$homeserver_dir/docker-compose.yml"
config="$homeserver_dir/config/gatus/config.yaml"
dynamic="$homeserver_dir/config/traefik/dynamic/services.yml"
glance="$homeserver_dir/config/glance/glance.yml"
matrix="$scripts_dir/hostname-matrix.tsv"
verifier="$scripts_dir/verify-hostname-matrix.sh"
root=$(mktemp -d /tmp/n33lab-gatus.XXXXXX)
trap 'rm -rf "$root"' EXIT
trap 'exit 1' HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_fail() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $*"
  fi
}

assert_safe_migration() {
  compose_file=$1
  ignore_file=$2
  prompt_file=$3
  grep -Fxq 'os/homeserver/data/' "$ignore_file" || return 1
  if grep -Eiq 'uptime-kuma|docker compose down -v|docker (volume|system|image) prune|rm[[:space:]]+(-[[:alnum:]]+[[:space:]]+)*[^#]*data/|git (reset --hard|clean)' \
    "$compose_file" "$homeserver_dir/deploy.sh" "$homeserver_dir/recover-env.sh" "$homeserver_dir/forgejo-migrate.sh"; then
    return 1
  fi
  grep -Fq "Never run \`docker compose down -v\`, any prune command" "$prompt_file" \
    || return 1
  grep -Fq 'destructive storage operation' "$prompt_file" \
    || return 1
  if grep -Eiq '^[[:space:]]*(rm[[:space:]]+(-[[:alnum:]]+[[:space:]]+)*[^#]*data/|docker compose down -v|docker (volume|system|image) prune|.*data/uptime-kuma.*(delete|remove|rm))' "$prompt_file"; then
    return 1
  fi
}

grep -Eq '^  gatus:$' "$compose" || fail 'Gatus service is missing'
if grep -Eq '^  uptime-kuma:|louislam/uptime-kuma|com\.centurylinklabs\.watchtower\.enable' "$compose"; then
  fail 'legacy monitoring service remains active'
fi

awk '
  /^  gatus:$/ { active = 1 }
  active && /^  [A-Za-z0-9_-]+:$/ && $1 != "gatus:" { exit }
  active { print }
' "$compose" >"$root/gatus-service"
for required in 'image: ghcr.io/twin/gatus@sha256:c5f210d095fa78e6efaa20ffeb14803f2ba4f10615e16a6d12087697149617f0' './config/gatus:/config:ro' \
  './data/gatus:/var/lib/gatus' 'host.docker.internal:host-gateway'; do
  grep -Fq "$required" "$root/gatus-service" || fail "Gatus Compose contract is missing: $required"
done
if grep -Eq '^    env_file:|gatus\.env' "$root/gatus-service"; then
  fail 'Gatus native auth attachment remains active'
fi
grep -Fq "Host(\`uptime.{{ env \"DOMAIN\" }}\`)" "$dynamic" || fail 'Gatus file-provider route is missing'
grep -Fq 'url: http://gatus:8080' "$dynamic" || fail 'Gatus file-provider service is missing'
grep -Fq '/var/run/docker.sock' "$root/gatus-service" && fail 'Gatus has Docker socket access'
grep -Fq './data/uptime-kuma' "$compose" && fail 'new Compose references old Kuma data'
assert_safe_migration "$compose" "$homeserver_dir/../../.gitignore" "$homeserver_dir/UPDATE_IMAGES.md" \
  || fail 'migration safety contract failed'

sed '/^services:/a\  unsafe:\n    image: alpine:latest\n    command: docker compose down -v' "$compose" >"$root/unsafe-compose.yml"
expect_fail assert_safe_migration "$root/unsafe-compose.yml" "$homeserver_dir/../../.gitignore" "$homeserver_dir/UPDATE_IMAGES.md"
cp "$homeserver_dir/UPDATE_IMAGES.md" "$root/unsafe-update.md"
printf '%s\n' 'rm -rf ./data/uptime-kuma' >>"$root/unsafe-update.md"
expect_fail assert_safe_migration "$compose" "$homeserver_dir/../../.gitignore" "$root/unsafe-update.md"

[ -f "$config" ] && [ ! -L "$config" ] || fail 'tracked Gatus config is missing'
cat >"$root/validate.py" <<'PY'
import sys
import yaml

expected = {
    "Glance", "Traefik", "Dockhand", "Pi-hole", "Dozzle", "Open WebUI",
    "Excalidraw", "qBittorrent", "Immich", "File Browser", "Backrest",
    "Home Assistant", "ESPHome", "Music Assistant", "Node-RED", "Forgejo",
}
groups = {"Infrastructure", "Apps", "Storage", "Smart Home", "Git"}
with open(sys.argv[1], encoding="utf-8") as source:
    data = yaml.safe_load(source)
assert data["web"]["port"] == 8080
assert data["ui"]["title"]
assert data["storage"] == {"type": "sqlite", "path": "/var/lib/gatus/db.sqlite"}
assert "security" not in data
endpoints = data["endpoints"]
names = [endpoint["name"] for endpoint in endpoints]
assert len(names) == len(set(names))
assert set(names) == expected
assert {endpoint["group"] for endpoint in endpoints} == groups
for endpoint in endpoints:
    assert endpoint["interval"] == "1m"
    assert endpoint["client"]["timeout"] == "10s"
    assert endpoint["conditions"] == ["[STATUS] > 0", "[STATUS] < 500", "[RESPONSE_TIME] < 5000"]
    url = endpoint["url"].lower()
    assert url.startswith("http://")
    assert "ugreen" not in url and "nas.local" not in url and "192.168.1.33" not in url
PY

python "$root/validate.py" "$config" || fail 'Gatus YAML structure is invalid'

for mutation in duplicate missing accepts-5xx; do
  python - "$config" "$root/$mutation.yaml" "$mutation" <<'PY'
import copy
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as source:
    data = yaml.safe_load(source)
if sys.argv[3] == "duplicate":
    data["endpoints"].append(copy.deepcopy(data["endpoints"][0]))
elif sys.argv[3] == "missing":
    data["endpoints"].pop()
else:
    data["endpoints"][0]["conditions"][0] = "[STATUS] <= 500"
with open(sys.argv[2], "w", encoding="utf-8") as destination:
    yaml.safe_dump(data, destination, sort_keys=False)
PY
  expect_fail python "$root/validate.py" "$root/$mutation.yaml"
done

grep -Fq 'title: Gatus' "$glance" || fail 'Glance title is not Gatus'
grep -Fq 'check-url: http://gatus:8080' "$glance" || fail 'Glance Gatus check URL is missing'
grep -Fq 'icon: di:gatus' "$glance" || fail 'Glance Gatus icon is missing'
grep -Fq -- '--ping=true' "$compose" || fail 'Traefik ping is disabled'
grep -Fq -- '--ping.entrypoint=ping' "$compose" || fail 'Traefik ping entrypoint is missing'
grep -Fq -- '--entrypoints.ping.address=:8082' "$compose" || fail 'Traefik ping entrypoint address is missing'
if grep -Eq '(^|[" ])([0-9.]+:)?8082:|(^|[" ])8082:[0-9]+' "$compose"; then
  fail 'Traefik ping entrypoint is externally published'
fi
grep -Fq 'check-url: http://traefik:8082/ping' "$glance" || fail 'Glance Traefik check URL is missing'
grep -Fq 'url: https://192.168.1.33:9443/desktop/?os=ugospro#/' "$glance" || fail 'UGREEN user URL is not canonical'
grep -Fq 'check-url: http://host.docker.internal:9999' "$glance" || fail 'UGREEN server-side check URL is missing'
grep -Fq 'alt-status-codes: [307]' "$glance" || fail 'UGREEN redirect status acceptance is missing'
grep -Fq 'uptime.n33lab.com	http	gatus	gatus:8080	none' "$matrix" \
  || fail 'hostname matrix does not map Gatus'
grep -Fq '"uptime.n33lab.com gatus gatus:8080"' "$verifier" \
  || fail 'hostname verifier does not map Gatus'

for attachment in authelia-jwt authelia-session authelia-storage-encryption authelia-users; do
  grep -Fq "$attachment" "$homeserver_dir/.env.example" || fail "attachment documentation omits $attachment"
  grep -Fq "$attachment" "$homeserver_dir/recover-env.sh" || fail "recovery omits $attachment"
  grep -Fq "$attachment" "$homeserver_dir/deploy.sh" || fail "deploy preflight omits $attachment"
done
grep -Fq 'restored 15 validated runtime attachments' "$homeserver_dir/recover-env.sh" \
  || fail 'recovery attachment count is not 15'
if grep -Eq 'gatus\.env|traefik-users|GATUS_' "$homeserver_dir/deploy.sh" "$homeserver_dir/recover-env.sh" "$homeserver_dir/.env.example"; then
  fail 'retired authentication attachment remains in active contracts'
fi

printf '%s\n' 'gatus_config_status=PASS'
