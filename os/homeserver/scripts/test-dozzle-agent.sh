#!/bin/sh
set -eu
umask 077

script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
compose=${1:-"$script_dir/../docker-compose.yml"}
evidence=${TASK9_EVIDENCE:-}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/n33lab-docker-socket-proxy.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

service() {
    awk -v target="$2" '
        /^services:/ { in_services=1; next }
        in_services && /^  [A-Za-z0-9-]+:/ {
            name=$1; sub(/:$/, "", name); active=(name == target)
        }
        in_services && active { print }
    ' "$1"
}

check() {
    file=$1
    proxy=$(service "$file" docker-socket-proxy)
    [ "$(service "$file" dozzle | grep -Fc 'DOZZLE_REMOTE_HOST=tcp://docker-socket-proxy:2375')" = 1 ] || return 1
    ! service "$file" dozzle | grep -Fq '/var/run/docker.sock' || return 1
    printf '%s\n' "$proxy" | grep -Fq 'image: tecnativa/docker-socket-proxy@sha256:753044cb0851ce53ab44c2504872ff02ae37be9c294fa8abea3754074e61eab4' || return 1
    [ "$(printf '%s\n' "$proxy" | grep -Fc '/var/run/docker.sock:/var/run/docker.sock:ro')" = 1 ] || return 1
    ! printf '%s\n' "$proxy" | grep -Eq '^    ports:' || return 1
    printf '%s\n' "$proxy" | grep -Fxq '      - CONTAINERS=1' || return 1
    printf '%s\n' "$proxy" | grep -Fxq '      - INFO=1' || return 1
    printf '%s\n' "$proxy" | grep -Fxq '      - EVENTS=1' || return 1
    printf '%s\n' "$proxy" | grep -Fxq '      - POST=0' || return 1
    ! printf '%s\n' "$proxy" | grep -Eq '(^|[[:space:]])(AUTH|BUILD|COMMIT|CONFIGS|DISTRIBUTION|IMAGES|NETWORKS|NODES|PLUGINS|SECRETS|SERVICES|SESSION|SWARM|SYSTEM|TASKS|VOLUMES)=' || return 1
    [ "$(grep -Ec '/var/run/docker.sock(:|$)' "$file")" = 2 ] || return 1
    ! grep -Eq '(^|[^0-9])2375:2375([^0-9]|$)' "$file" || return 1
    ! grep -Eq '(^|[^0-9])7007:7007([^0-9]|$)' "$file" || return 1
    grep -A2 '^  dozzle_agent:' "$file" | grep -Fq 'internal: true' || return 1
    grep -A4 '^  dozzle_agent:' "$file" | grep -Fq 'driver: bridge' || return 1
    service "$file" dozzle | grep -A3 '^    networks:' | grep -Fq '      - traefik' || return 1
    service "$file" dozzle | grep -A3 '^    networks:' | grep -Fq '      - dozzle_agent' || return 1
    printf '%s\n' "$proxy" | grep -A2 '^    networks:' | grep -Fq '      - dozzle_agent' || return 1
    ! printf '%s\n' "$proxy" | grep -A2 '^    networks:' | grep -Fq 'traefik' || return 1
}

check "$compose" || fail 'Docker socket proxy wiring is invalid'

awk '/^  docker-socket-proxy:/{skip=1; next} skip && /^  [A-Za-z0-9-]+:/{skip=0} !skip{print}' "$compose" >"$tmp/missing-proxy.yml"
if check "$tmp/missing-proxy.yml"; then fail 'missing socket proxy was accepted'; fi
sed '/DOZZLE_REMOTE_HOST=tcp:\/\/docker-socket-proxy:2375/d' "$compose" >"$tmp/missing-env.yml"
if check "$tmp/missing-env.yml"; then fail 'missing socket proxy endpoint was accepted'; fi
sed '/      - POST=0/d' "$compose" >"$tmp/missing-post.yml"
if check "$tmp/missing-post.yml"; then fail 'missing POST deny setting was accepted'; fi
sed 's/      - POST=0/      - POST=1/' "$compose" >"$tmp/post-enabled.yml"
if check "$tmp/post-enabled.yml"; then fail 'enabled POST setting was accepted'; fi
awk '!/\/var\/run\/docker\.sock:/' "$compose" >"$tmp/missing-socket.yml"
if check "$tmp/missing-socket.yml"; then fail 'missing proxy socket was accepted'; fi

if [ -n "$evidence" ]; then
    evidence_dir=$(dirname "$evidence")
    [ -d "$evidence_dir" ] && [ ! -L "$evidence_dir" ] || fail 'evidence directory is invalid'
    temporary=$(mktemp "$evidence_dir/.task9.XXXXXX")
    {
        printf '%s\n' 'check_identifier=task-9-docker-socket-proxy'
        printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf '%s\n' 'execution_node=workstation' 'file_mode=600' 'status=PASS' 'test_exit_code=0'
    } >"$temporary"
    chmod 600 "$temporary"
    mv "$temporary" "$evidence"
fi
printf '%s\n' 'Docker socket proxy checks passed'
