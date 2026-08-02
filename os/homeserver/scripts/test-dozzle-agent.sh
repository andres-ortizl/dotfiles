#!/bin/sh
set -eu
umask 077

script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
compose=${1:-"$script_dir/../docker-compose.yml"}
evidence=${TASK9_EVIDENCE:-}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/n33lab-dozzle-agent.XXXXXX")
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
    digest=$(service "$file" dozzle | awk '$1 == "image:" { print $2 }')
    [ -n "$digest" ] || return 1
    [ "$digest" = "amir20/dozzle@sha256:1c1060cfb5402093c4e0f03f3534d7deaffeb0a6f6dd034e7c5f244603f35fb3" ] || return 1
    [ "$(service "$file" dozzle-agent | awk '$1 == "image:" { print $2 }')" = "$digest" ] || return 1
    service "$file" dozzle | grep -Fq 'DOZZLE_REMOTE_AGENT=dozzle-agent:7007' || return 1
    ! service "$file" dozzle | grep -Fq '/var/run/docker.sock' || return 1
    [ "$(service "$file" dozzle-agent | grep -Fc '/var/run/docker.sock:/var/run/docker.sock:ro')" = 1 ] || return 1
    service "$file" dozzle-agent | grep -Fxq '    command: agent' || return 1
    service "$file" dozzle-agent | grep -Fq '/var/run/docker.sock:/var/run/docker.sock:ro' || return 1
    ! service "$file" dozzle-agent | grep -Eq '^    ports:' || return 1
    ! grep -Eq '(^|[^0-9])7007:7007([^0-9]|$)' "$file" || return 1
    grep -A2 '^  dozzle_agent:' "$file" | grep -Fq 'internal: true' || return 1
    grep -A4 '^  dozzle_agent:' "$file" | grep -Fq 'driver: bridge' || return 1
    service "$file" dozzle | grep -A3 '^    networks:' | grep -Fq '      - traefik' || return 1
    service "$file" dozzle | grep -A3 '^    networks:' | grep -Fq '      - dozzle_agent' || return 1
    service "$file" dozzle-agent | grep -A2 '^    networks:' | grep -Fq '      - dozzle_agent' || return 1
    ! service "$file" dozzle-agent | grep -A2 '^    networks:' | grep -Fq 'traefik' || return 1
}

check "$compose" || fail 'Dozzle Agent wiring is invalid'

awk '/^  dozzle-agent:/{skip=1; next} skip && /^  [A-Za-z0-9-]+:/{skip=0} !skip{print}' "$compose" >"$tmp/missing-agent.yml"
if check "$tmp/missing-agent.yml"; then fail 'missing agent was accepted'; fi
sed '/DOZZLE_REMOTE_AGENT=dozzle-agent:7007/d' "$compose" >"$tmp/missing-env.yml"
if check "$tmp/missing-env.yml"; then fail 'missing agent endpoint was accepted'; fi
awk '!/\/var\/run\/docker\.sock:/' "$compose" >"$tmp/missing-socket.yml"
if check "$tmp/missing-socket.yml"; then fail 'missing agent socket was accepted'; fi

if [ -n "$evidence" ]; then
    evidence_dir=$(dirname "$evidence")
    [ -d "$evidence_dir" ] && [ ! -L "$evidence_dir" ] || fail 'evidence directory is invalid'
    temporary=$(mktemp "$evidence_dir/.task9.XXXXXX")
    {
        printf '%s\n' 'check_identifier=task-9-dozzle-agent'
        printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf '%s\n' 'execution_node=workstation' 'file_mode=600' 'status=PASS' 'test_exit_code=0'
    } >"$temporary"
    chmod 600 "$temporary"
    mv "$temporary" "$evidence"
fi
printf '%s\n' 'Dozzle Agent checks passed'
