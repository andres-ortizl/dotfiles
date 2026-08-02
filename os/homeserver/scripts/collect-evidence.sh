#!/bin/sh
set -eu
umask 077

usage() { printf '%s\n' 'Usage: collect-evidence.sh --manifest FILE --round ID --destination DIR'; }
fail() { printf '%s\n' "$1" >&2; exit 1; }
require_gnu_tools() {
    for tool in stat timeout sha256sum; do command -v "$tool" >/dev/null 2>&1 || fail "required tool unavailable: $tool"; done
    stat --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU stat is required'
    timeout --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU timeout is required'
    sha256sum --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU sha256sum is required'
}
manifest_value() { awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print }' "$manifest"; }
protected_file() { [ -f "$1" ] && [ ! -L "$1" ] && [ "$(stat -c %a "$1")" = 600 ] && [ "$(stat -c %u "$1")" = "$(id -u)" ]; }

manifest=
round=
destination=
while [ "$#" -gt 0 ]; do
    case $1 in
        --manifest) [ "$#" -ge 2 ] || fail 'missing value for --manifest'; manifest=$2; shift 2 ;;
        --round) [ "$#" -ge 2 ] || fail 'missing value for --round'; round=$2; shift 2 ;;
        --destination) [ "$#" -ge 2 ] || fail 'missing value for --destination'; destination=$2; shift 2 ;;
        --help) usage; exit 0 ;;
        *) fail "unknown option: $1" ;;
    esac
done
[ -n "$manifest" ] && [ -n "$round" ] && [ -n "$destination" ] || fail 'all inputs are required'
require_gnu_tools
protected_file "$manifest" || fail 'manifest must be owned by the current user with mode 600'
grep -Eq '^(NAS_ENDPOINT|EXTERNAL_ENDPOINT)=[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$' "$manifest" || fail 'malformed worker manifest'
if ! awk -F= '{ if ($1 != "NAS_ENDPOINT" && $1 != "EXTERNAL_ENDPOINT") exit 1; count[$1]++ } END { if (count["NAS_ENDPOINT"] != 1 || count["EXTERNAL_ENDPOINT"] != 1) exit 1 }' "$manifest"; then
    fail 'worker manifest must contain exactly two unique endpoints'
fi
case $round in *[!A-Za-z0-9._-]*|''|.*|*..*) fail 'invalid round identifier' ;; esac
case $destination in /*) ;; *) fail 'destination must be absolute' ;; esac
case $destination in *'/../'*|*'/./'*|*'//'*) fail 'unsafe destination' ;; esac
[ -d "$destination" ] && [ ! -L "$destination" ] || fail 'destination must be an existing regular directory'

nas_endpoint=$(manifest_value NAS_ENDPOINT)
external_endpoint=$(manifest_value EXTERNAL_ENDPOINT)
for endpoint in "$nas_endpoint" "$external_endpoint"; do
    printf '%s\n' "$endpoint" | grep -Eq '^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$' || fail 'invalid evidence endpoint'
done

incoming=$(mktemp -d "$destination/.incoming.XXXXXX")
trap 'rm -rf "$incoming"' EXIT
trap 'exit 1' HUP INT TERM
for item in 'nas runtime.txt' 'nas runtime.txt.sha256' 'external external.txt' 'external external.txt.sha256'; do
    node=${item%% *}
    file=${item#* }
    if [ "$node" = nas ]; then endpoint=$nas_endpoint; else endpoint=$external_endpoint; fi
    scp -q -o BatchMode=yes -o StrictHostKeyChecking=yes "$endpoint:/var/tmp/n33lab-evidence/$round/$node/$file" "$incoming/$file" >/dev/null 2>&1 || fail "authenticated transfer failed: $node/$file"
done

for file in runtime.txt external.txt; do
    checksum="$file.sha256"
    [ -f "$incoming/$file" ] && [ ! -L "$incoming/$file" ] || fail "invalid transferred file: $file"
    [ -f "$incoming/$checksum" ] && [ ! -L "$incoming/$checksum" ] || fail "invalid transferred file: $checksum"
    [ "$(stat -c %a "$incoming/$file")" = 600 ] && [ "$(stat -c %a "$incoming/$checksum")" = 600 ] || fail "wrong transferred mode: $file"
    [ "$(stat -c %u "$incoming/$file")" = "$(id -u)" ] && [ "$(stat -c %u "$incoming/$checksum")" = "$(id -u)" ] || fail "wrong transferred owner: $file"
    grep -Eq "^[0-9a-f]{64}  $file$" "$incoming/$checksum" || fail "invalid checksum record: $file"
    (cd "$incoming" && sha256sum -c "$checksum" >/dev/null 2>&1) || fail "checksum mismatch: $file"
    if grep -Evq '^(check_identifier=[A-Za-z0-9-]+|timestamp_utc=[0-9TZ:+-]+|execution_node=(nas|external)|git_commit=[0-9a-f]+|changed_path=[A-Za-z0-9_./*-]+|status=(PASS|FAIL|blocked|reference_validated)|file_mode=[0-7]+|listener_(address|port|protocol|probe_state)=[A-Za-z0-9:._/-]+|test_exit_code=[0-9]+|error_code=[A-Za-z0-9._-]+)$' "$incoming/$file"; then
        fail "non-allowlisted evidence field: $file"
    fi
done

for file in runtime.txt runtime.txt.sha256 external.txt external.txt.sha256; do
    [ ! -e "$destination/$file" ] || fail "destination already contains: $file"
    cp "$incoming/$file" "$destination/$file"
    chmod 600 "$destination/$file"
done
rm -rf "$incoming"
trap - EXIT HUP INT TERM
printf '%s\n' 'status=PASS files_installed=4'
