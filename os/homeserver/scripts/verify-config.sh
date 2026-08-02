#!/bin/sh
set -eu
umask 077

usage() { printf '%s\n' 'Usage: verify-config.sh --base COMMIT --compose FILE --fixtures-dir DIR --evidence FILE'; }
fail() { printf '%s\n' "$1" >&2; exit 1; }
require_gnu_tools() {
    for tool in stat timeout sha256sum; do command -v "$tool" >/dev/null 2>&1 || fail "required tool unavailable: $tool"; done
    stat --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU stat is required'
    timeout --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU timeout is required'
    sha256sum --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU sha256sum is required'
}

base=
compose=
fixtures=
evidence=
while [ "$#" -gt 0 ]; do
    case $1 in
        --base) [ "$#" -ge 2 ] || fail 'missing value for --base'; base=$2; shift 2 ;;
        --compose) [ "$#" -ge 2 ] || fail 'missing value for --compose'; compose=$2; shift 2 ;;
        --fixtures-dir) [ "$#" -ge 2 ] || fail 'missing value for --fixtures-dir'; fixtures=$2; shift 2 ;;
        --evidence) [ "$#" -ge 2 ] || fail 'missing value for --evidence'; evidence=$2; shift 2 ;;
        --help) usage; exit 0 ;;
        *) fail "unknown option: $1" ;;
    esac
done
[ -n "$base" ] && [ -n "$compose" ] && [ -n "$fixtures" ] && [ -n "$evidence" ] || fail 'all inputs are required'
require_gnu_tools
git cat-file -e "$base^{commit}" 2>/dev/null || fail 'base is not a commit'
[ -f "$compose" ] && [ ! -L "$compose" ] || fail 'compose must be a regular file'
[ ! -e "$fixtures" ] || fail 'fixtures directory already exists'
fixtures_parent=$(dirname "$fixtures")
[ -d "$fixtures_parent" ] && [ ! -L "$fixtures_parent" ] || fail 'fixtures parent is invalid'
evidence_dir=$(dirname "$evidence")
[ -d "$evidence_dir" ] && [ ! -L "$evidence_dir" ] || fail 'evidence directory is invalid'

trap 'rm -rf "$fixtures"' EXIT
trap 'exit 1' HUP INT TERM
mkdir -m 700 "$fixtures"
fake_env="$fixtures/homeserver.env"
{
    printf '%s\n' 'DOMAIN=n33lab.com' 'TZ=UTC' 'PIHOLE_PASSWORD_FILE=/run/secrets/pihole-password'
    printf '%s\n' 'DB_PASSWORD_FILE=/run/secrets/database-password' 'TAILSCALE_AUTHKEY_FILE=/run/secrets/tailscale-key'
} >"$fake_env"
chmod 600 "$fake_env"

result=0
git diff --check "$base" -- os/homeserver >/dev/null 2>&1 || result=1
if command -v shellcheck >/dev/null 2>&1; then
    for script in "$(dirname "$0")"/*.sh; do shellcheck -s sh "$script" >/dev/null 2>&1 || result=1; done
else
    result=1
fi
if command -v docker >/dev/null 2>&1; then
    docker compose --env-file "$fake_env" -f "$compose" config --quiet >/dev/null 2>&1 || result=1
else
    result=1
fi
grep -Fq "\${DOMAIN:-localhost}" "$compose" && result=1
grep -Eq '^[[:space:]]*privileged:[[:space:]]*true' "$compose" && result=1
grep -Eq '(traefik|haproxy|watchtower):latest' "$compose" && result=1
git diff --cached --no-ext-diff -- os/homeserver | grep -Eqi '(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|password[=:][^$]|token[=:][^$])' && result=1

compose_dir=$(dirname "$compose")
for config in "$compose_dir"/config/docker-api-proxy/*.cfg; do
    [ -e "$config" ] || continue
    command -v haproxy >/dev/null 2>&1 && haproxy -c -f "$config" >/dev/null 2>&1 || result=1
done
firewall="$compose_dir/config/firewall/n33lab.nft"
if [ -e "$firewall" ]; then
    command -v nft >/dev/null 2>&1 && nft -c -f "$firewall" >/dev/null 2>&1 || result=1
fi

temporary=$(mktemp "$evidence_dir/.config.XXXXXX")
{
    printf '%s\n' 'check_identifier=F2-config' 'execution_node=workstation'
    printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'git_commit=%s\n' "$base"
    printf '%s\n' 'file_mode=600'
    if [ "$result" -eq 0 ]; then printf '%s\n' 'status=PASS'; else printf '%s\n' 'status=FAIL'; fi
    printf 'test_exit_code=%s\n' "$result"
} >"$temporary"
chmod 600 "$temporary"
mv "$temporary" "$evidence"
exit "$result"
