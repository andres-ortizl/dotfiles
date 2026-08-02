#!/bin/sh
set -eu
umask 077

usage() { printf '%s\n' 'Usage: verify-scope.sh --base COMMIT --scope FILE --evidence FILE'; }
fail() { printf '%s\n' "$1" >&2; exit 1; }
require_gnu_tools() {
    for tool in stat timeout sha256sum; do command -v "$tool" >/dev/null 2>&1 || fail "required tool unavailable: $tool"; done
    stat --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU stat is required'
    timeout --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU timeout is required'
    sha256sum --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU sha256sum is required'
}

base=
scope=
evidence=
while [ "$#" -gt 0 ]; do
    case $1 in
        --base) [ "$#" -ge 2 ] || fail 'missing value for --base'; base=$2; shift 2 ;;
        --scope) [ "$#" -ge 2 ] || fail 'missing value for --scope'; scope=$2; shift 2 ;;
        --evidence) [ "$#" -ge 2 ] || fail 'missing value for --evidence'; evidence=$2; shift 2 ;;
        --help) usage; exit 0 ;;
        *) fail "unknown option: $1" ;;
    esac
done
[ -n "$base" ] && [ -n "$scope" ] && [ -n "$evidence" ] || fail 'all inputs are required'
require_gnu_tools
git cat-file -e "$base^{commit}" 2>/dev/null || fail 'base is not a commit'
[ -f "$scope" ] && [ ! -L "$scope" ] || fail 'scope must be a regular file'
evidence_dir=$(dirname "$evidence")
[ -d "$evidence_dir" ] && [ ! -L "$evidence_dir" ] || fail 'evidence directory is invalid'

changed=$(mktemp "$evidence_dir/.scope-changed.XXXXXX")
temporary=$(mktemp "$evidence_dir/.scope.XXXXXX")
trap 'rm -f "$changed" "$temporary"' EXIT
trap 'exit 1' HUP INT TERM
git diff --name-only --diff-filter=ACMR "$base" -- >"$changed"
result=0
while IFS= read -r path; do
    [ -n "$path" ] || continue
    case $path in
        os/homeserver/*|.gitignore) ;;
        *) result=1 ;;
    esac
    case $path in
        *secrets/*|*acme.json|*.pem|*.key|*.p12|*.db|*.sqlite|*qa-manifest.env) result=1 ;;
    esac
done <"$changed"

set -- os/homeserver/docker-compose.yml os/homeserver/.env.example os/homeserver/config os/homeserver/deploy.sh os/homeserver/recover-env.sh os/homeserver/forgejo-migrate.sh
git grep -Eq '(cloudflared|cloudflare[[:space:]_-]*tunnel|network_mode:[[:space:]]*host.*removed|docker compose down -v|git reset --hard|git clean|docker (system|volume|image) prune)' -- "$@" 2>/dev/null && result=1
git grep -Eq '(lab\.lan|nasito\.local|192\.168\.1\.193|\$\{DOMAIN:-localhost\})' -- "$@" 2>/dev/null && result=1
git grep -Eq '(^|[^0-9])(222|6881|8097|9443|9999)([^0-9]|$)' -- os/homeserver/docker-compose.yml 2>/dev/null || result=1
git grep -Eq '(BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|password[=:][^$]|token[=:][^$])' -- "$@" 2>/dev/null && result=1

{
    printf '%s\n' 'check_identifier=F4-scope' 'execution_node=workstation'
    printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'git_commit=%s\n' "$base"
    if [ "$result" -eq 0 ]; then printf '%s\n' 'status=PASS'; else printf '%s\n' 'status=FAIL'; fi
    printf 'test_exit_code=%s\n' "$result"
} >"$temporary"
chmod 600 "$temporary"
mv "$temporary" "$evidence"
trap - EXIT HUP INT TERM
exit "$result"
