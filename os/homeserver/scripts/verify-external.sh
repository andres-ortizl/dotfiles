#!/bin/sh
set -eu
umask 077

usage() { printf '%s\n' 'Usage: verify-external.sh --qa-manifest FILE --tcp-ports LIST --udp-ports LIST --output-dir DIR'; }
fail() { printf '%s\n' "$1" >&2; exit 1; }
require_gnu_tools() {
    for tool in stat timeout sha256sum; do command -v "$tool" >/dev/null 2>&1 || fail "required tool unavailable: $tool"; done
    stat --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU stat is required'
    timeout --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU timeout is required'
    sha256sum --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU sha256sum is required'
}
manifest_value() { awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print }' "$manifest"; }
protected_file() { [ -f "$1" ] && [ ! -L "$1" ] && [ "$(stat -c %a "$1")" = 600 ] && [ "$(stat -c %u "$1")" = "$(id -u)" ]; }
safe_path() { case $1 in /*) ;; *) return 1 ;; esac; case $1 in *'/../'*|*'/./'*|*'//'*) return 1 ;; esac; }

manifest=
tcp_ports=
udp_ports=
output_dir=
required_tcp='22,53,80,443,222,1883,3333,6052,6881,8095,8097,8123,8883,9090,9443,9999'
required_udp='53,67,68,6881'
while [ "$#" -gt 0 ]; do
    case $1 in
        --qa-manifest) [ "$#" -ge 2 ] || fail 'missing value for --qa-manifest'; manifest=$2; shift 2 ;;
        --tcp-ports) [ "$#" -ge 2 ] || fail 'missing value for --tcp-ports'; tcp_ports=$2; shift 2 ;;
        --udp-ports) [ "$#" -ge 2 ] || fail 'missing value for --udp-ports'; udp_ports=$2; shift 2 ;;
        --output-dir) [ "$#" -ge 2 ] || fail 'missing value for --output-dir'; output_dir=$2; shift 2 ;;
        --help) usage; exit 0 ;;
        *) fail "unknown option: $1" ;;
    esac
done
[ -n "$manifest" ] && [ -n "$tcp_ports" ] && [ -n "$udp_ports" ] && [ -n "$output_dir" ] || fail 'all inputs are required'
require_gnu_tools
[ "$tcp_ports" = "$required_tcp" ] || fail 'TCP port list must exactly match the approved matrix'
[ "$udp_ports" = "$required_udp" ] || fail 'UDP port list must exactly match the approved matrix'
protected_file "$manifest" || fail 'manifest must be owned by the current user with mode 600'
grep -Eq '^[A-Z][A-Z0-9_]*=[^[:space:]]+$' "$manifest" || fail 'malformed manifest'
if ! awk -F= '{ count[$1]++ } END { for (key in count) if (count[key] != 1) exit 1 }' "$manifest"; then
    fail 'duplicate manifest key'
fi
while IFS='=' read -r key value; do
    case $key in MODE|WAN_IPV4_FILE|NAS_GLOBAL_IPV6_FILE|PUBLIC_DNS_RESOLVERS_FILE|EXTERNAL_PROBE_COMMAND_FILE) ;; *) fail "unknown manifest key: $key" ;; esac
    [ -n "$value" ] || fail "empty manifest value: $key"
done <"$manifest"
mode=$(manifest_value MODE)
case $mode in reference|execute) ;; *) fail 'manifest MODE must be reference or execute' ;; esac
for key in WAN_IPV4_FILE NAS_GLOBAL_IPV6_FILE PUBLIC_DNS_RESOLVERS_FILE; do
    value=$(manifest_value "$key")
    if [ -z "$value" ] || ! safe_path "$value" || ! protected_file "$value"; then fail "invalid protected reference: $key"; fi
done
probe=$(manifest_value EXTERNAL_PROBE_COMMAND_FILE)
if [ -z "$probe" ] || ! safe_path "$probe"; then fail 'invalid EXTERNAL_PROBE_COMMAND_FILE'; fi
if [ -e "$probe" ] && { [ ! -f "$probe" ] || [ -L "$probe" ] || [ ! -x "$probe" ] || [ "$(stat -c %u "$probe")" != "$(id -u)" ]; }; then fail 'invalid EXTERNAL_PROBE_COMMAND_FILE'; fi
case $output_dir in /*) ;; *) fail 'output directory must be absolute' ;; esac
safe_path "$output_dir" || fail 'unsafe output directory'
if [ -e "$output_dir" ]; then [ -d "$output_dir" ] && [ ! -L "$output_dir" ] || fail 'output directory is invalid'; else
    [ -d "$(dirname "$output_dir")" ] || fail 'output parent is missing'
    mkdir -m 700 "$output_dir"
fi
chmod 700 "$output_dir"

result=1
state=reference_validated
temporary=$(mktemp "$output_dir/.external.XXXXXX")
trap 'rm -f "$temporary"' EXIT
trap 'exit 1' HUP INT TERM
{
    printf '%s\n' 'check_identifier=F3-external' 'execution_node=external'
    printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [ "$mode" = execute ]; then
        if ! safe_path "$probe" || [ ! -f "$probe" ] || [ -L "$probe" ] || [ ! -x "$probe" ] || [ "$(stat -c %u "$probe" 2>/dev/null)" != "$(id -u)" ]; then
            printf '%s\n' 'check_identifier=external-probe' 'status=blocked' 'test_exit_code=127'
            result=1
            state=blocked
        elif timeout 120 "$probe" --qa-manifest "$manifest" --tcp-ports "$tcp_ports" --udp-ports "$udp_ports" >/dev/null 2>&1; then
            printf '%s\n' 'check_identifier=external-probe' 'status=PASS' 'test_exit_code=0'
            result=0
            state=PASS
        else
            code=$?
            printf '%s\n' 'check_identifier=external-probe' 'status=FAIL'
            printf 'test_exit_code=%s\n' "$code"
            result=1
            state=FAIL
        fi
    fi
    printf 'status=%s\n' "$state"
    printf 'test_exit_code=%s\n' "$result"
} >"$temporary"
chmod 600 "$temporary"
mv "$temporary" "$output_dir/external.txt"
(cd "$output_dir" && sha256sum external.txt >external.txt.sha256)
chmod 600 "$output_dir/external.txt.sha256"
trap - EXIT HUP INT TERM
exit "$result"
