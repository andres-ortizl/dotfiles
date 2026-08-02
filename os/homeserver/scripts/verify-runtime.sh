#!/bin/sh
set -eu
umask 077

usage() { printf '%s\n' 'Usage: verify-runtime.sh --nas-ip IP --domain DOMAIN --qa-manifest FILE --output-dir DIR'; }
fail() { printf '%s\n' "$1" >&2; exit 1; }
require_gnu_tools() {
    for tool in stat timeout sha256sum; do command -v "$tool" >/dev/null 2>&1 || fail "required tool unavailable: $tool"; done
    stat --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU stat is required'
    timeout --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU timeout is required'
    sha256sum --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU sha256sum is required'
}
manifest_value() { awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print }' "$manifest"; }
protected_file() {
    [ -f "$1" ] && [ ! -L "$1" ] || return 1
    [ "$(stat -c %a "$1")" = 600 ] && [ "$(stat -c %u "$1")" = "$(id -u)" ]
}
safe_path() {
    case $1 in /*) ;; *) return 1 ;; esac
    case $1 in *'/../'*|*'/./'*|*'//'*) return 1 ;; esac
}

nas_ip=
domain=
manifest=
output_dir=
while [ "$#" -gt 0 ]; do
    case $1 in
        --nas-ip) [ "$#" -ge 2 ] || fail 'missing value for --nas-ip'; nas_ip=$2; shift 2 ;;
        --domain) [ "$#" -ge 2 ] || fail 'missing value for --domain'; domain=$2; shift 2 ;;
        --qa-manifest) [ "$#" -ge 2 ] || fail 'missing value for --qa-manifest'; manifest=$2; shift 2 ;;
        --output-dir) [ "$#" -ge 2 ] || fail 'missing value for --output-dir'; output_dir=$2; shift 2 ;;
        --help) usage; exit 0 ;;
        *) fail "unknown option: $1" ;;
    esac
done
[ -n "$nas_ip" ] && [ -n "$domain" ] && [ -n "$manifest" ] && [ -n "$output_dir" ] || fail 'all inputs are required'
require_gnu_tools
[ "$nas_ip" = 192.168.1.33 ] || fail 'unexpected NAS IP'
[ "$domain" = n33lab.com ] || fail 'unexpected domain'
protected_file "$manifest" || fail 'manifest must be owned by the current user with mode 600'
grep -Eq '^[A-Z][A-Z0-9_]*=[^[:space:]]+$' "$manifest" || fail 'malformed manifest'
if ! awk -F= '{ count[$1]++ } END { for (key in count) if (count[key] != 1) exit 1 }' "$manifest"; then
    fail 'duplicate manifest key'
fi
while IFS='=' read -r key value; do
    case $key in
        MODE|BASIC_AUTH_CREDENTIALS_FILE|HOME_ASSISTANT_CREDENTIALS_FILE|FORGEJO_TOKEN_FILE|ESPHOME_DEVICE_FILE|MUSIC_ASSISTANT_PLAYER_FILE|MQTT_CLIENT_FILES_FILE|ADMIN_IPV4_SET_FILE|CHECKS_DIR) ;;
        *) fail "unknown manifest key: $key" ;;
    esac
    [ -n "$value" ] || fail "empty manifest value: $key"
done <"$manifest"

mode=$(manifest_value MODE)
case $mode in reference|execute) ;; *) fail 'manifest MODE must be reference or execute' ;; esac
reference_keys='BASIC_AUTH_CREDENTIALS_FILE HOME_ASSISTANT_CREDENTIALS_FILE FORGEJO_TOKEN_FILE ESPHOME_DEVICE_FILE MUSIC_ASSISTANT_PLAYER_FILE MQTT_CLIENT_FILES_FILE ADMIN_IPV4_SET_FILE'
for key in $reference_keys; do
    value=$(manifest_value "$key")
    [ -n "$value" ] || fail "missing manifest key: $key"
    if ! safe_path "$value" || ! protected_file "$value"; then fail "invalid protected reference: $key"; fi
done
checks_dir=$(manifest_value CHECKS_DIR)
if [ -z "$checks_dir" ] || ! safe_path "$checks_dir"; then fail 'invalid CHECKS_DIR'; fi
if [ -e "$checks_dir" ] && { [ ! -d "$checks_dir" ] || [ -L "$checks_dir" ] || [ "$(stat -c %u "$checks_dir")" != "$(id -u)" ]; }; then fail 'invalid CHECKS_DIR'; fi

case $output_dir in /*) ;; *) fail 'output directory must be absolute' ;; esac
safe_path "$output_dir" || fail 'unsafe output directory'
if [ -e "$output_dir" ]; then [ -d "$output_dir" ] && [ ! -L "$output_dir" ] || fail 'output directory is invalid'; else
    [ -d "$(dirname "$output_dir")" ] || fail 'output parent is missing'
    mkdir -m 700 "$output_dir"
fi
chmod 700 "$output_dir"

checks='dns tls http auth websocket mqtt ports discovery ota playback forgejo pihole docker-api dhcp ssh ugreen'
result=1
state=reference_validated
blocked=0
temporary=$(mktemp "$output_dir/.runtime.XXXXXX")
trap 'rm -f "$temporary"' EXIT
trap 'exit 1' HUP INT TERM
{
    printf '%s\n' 'check_identifier=F3-runtime' 'execution_node=nas'
    printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [ "$mode" = execute ]; then
        result=0
        for check in $checks; do
            check_script="$checks_dir/$check-check"
            if [ ! -f "$check_script" ] || [ -L "$check_script" ] || [ ! -x "$check_script" ] || [ "$(stat -c %u "$check_script" 2>/dev/null)" != "$(id -u)" ]; then
                printf 'check_identifier=runtime-%s\nstatus=blocked\ntest_exit_code=127\n' "$check"
                result=1
                blocked=1
                continue
            fi
            if timeout 30 "$check_script" --nas-ip "$nas_ip" --domain "$domain" --qa-manifest "$manifest" >/dev/null 2>&1; then
                printf 'check_identifier=runtime-%s\nstatus=PASS\ntest_exit_code=0\n' "$check"
            else
                code=$?
                printf 'check_identifier=runtime-%s\nstatus=FAIL\ntest_exit_code=%s\n' "$check" "$code"
                result=1
            fi
        done
        if [ "$result" -eq 0 ]; then state=PASS; elif [ "$blocked" -eq 1 ]; then state=blocked; else state=FAIL; fi
    fi
    printf 'status=%s\n' "$state"
    printf 'test_exit_code=%s\n' "$result"
} >"$temporary"
chmod 600 "$temporary"
mv "$temporary" "$output_dir/runtime.txt"
(cd "$output_dir" && sha256sum runtime.txt >runtime.txt.sha256)
chmod 600 "$output_dir/runtime.txt.sha256"
trap - EXIT HUP INT TERM
exit "$result"
