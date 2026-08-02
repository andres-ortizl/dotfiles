#!/bin/sh
set -eu
umask 077

usage() {
    printf '%s\n' 'Usage: verify-plan-compliance.sh --base COMMIT --plan FILE --evidence FILE'
}

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

require_gnu_tools() {
    for tool in stat timeout sha256sum; do command -v "$tool" >/dev/null 2>&1 || fail "required tool unavailable: $tool"; done
    stat --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU stat is required'
    timeout --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU timeout is required'
    sha256sum --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU sha256sum is required'
}

base=
plan=
evidence=
while [ "$#" -gt 0 ]; do
    case $1 in
        --base) [ "$#" -ge 2 ] || fail 'missing value for --base'; base=$2; shift 2 ;;
        --plan) [ "$#" -ge 2 ] || fail 'missing value for --plan'; plan=$2; shift 2 ;;
        --evidence) [ "$#" -ge 2 ] || fail 'missing value for --evidence'; evidence=$2; shift 2 ;;
        --help) usage; exit 0 ;;
        *) fail "unknown option: $1" ;;
    esac
done
[ -n "$base" ] && [ -n "$plan" ] && [ -n "$evidence" ] || fail 'all inputs are required'
require_gnu_tools
[ -f "$plan" ] && [ ! -L "$plan" ] || fail 'plan must be a regular file'
git cat-file -e "$base^{commit}" 2>/dev/null || fail 'base is not a commit'
evidence_dir=$(dirname "$evidence")
[ -d "$evidence_dir" ] && [ ! -L "$evidence_dir" ] || fail 'evidence directory is invalid'
[ ! -e "$evidence" ] || [ ! -L "$evidence" ] || fail 'evidence path must not be a symlink'

task_files='task-1-deploy-preflight.txt
task-2-pihole-dns.txt
task-3-hostname-matrix.txt
task-4-acme-staging.txt
task-5-https-auth.txt
task-6-production-cutover.txt
task-7-mqtt-auth.txt
task-8-mqtt-tls.txt
task-9-docker-socket-proxy.txt
task-10-controlled-updates.txt
task-11-firewall.txt
task-12-legacy-retirement.txt
task-13-end-to-end.txt'
hostnames='n33lab.com
traefik.n33lab.com
docker.n33lab.com
pihole.n33lab.com
qbittorrent.n33lab.com
immich.n33lab.com
chat.n33lab.com
excalidraw.n33lab.com
uptime.n33lab.com
logs.n33lab.com
files.n33lab.com
backup.n33lab.com
ha.n33lab.com
ha-esphome.n33lab.com
ha-music.n33lab.com
ha-flows.n33lab.com
git.n33lab.com
mqtt.n33lab.com'

result=0
for task_file in $task_files; do
    grep -Fq "$task_file" "$plan" || result=1
    [ -f "$evidence_dir/$task_file" ] && [ ! -L "$evidence_dir/$task_file" ] || { result=1; continue; }
    [ "$(stat -c %a "$evidence_dir/$task_file")" = 600 ] || result=1
    grep -Eq '^status=(PASS|APPROVE)$' "$evidence_dir/$task_file" || result=1
done
for hostname in $hostnames; do
    grep -Fq "$hostname" "$plan" || result=1
done
grep -Fq '22,53,80,443,222,1883,3333,6052,6881,8095,8097,8123,8883,9090,9443,9999' "$plan" || result=1
grep -Fq '53,67,68,6881' "$plan" || result=1
for rollback in 'DNS/Pi-hole' 'Traefik/ACME' MQTT 'Docker socket proxy' Watchtower/update Firewall UGREEN URLs/config; do
    grep -Fiq "$rollback" "$plan" || result=1
done

temporary=$(mktemp "$evidence_dir/.plan-compliance.XXXXXX")
trap 'rm -f "$temporary"' EXIT
trap 'exit 1' HUP INT TERM
{
    printf '%s\n' 'check_identifier=F1-plan-compliance'
    printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\n' 'execution_node=workstation'
    printf 'git_commit=%s\n' "$base"
    if [ "$result" -eq 0 ]; then printf '%s\n' 'status=PASS'; else printf '%s\n' 'status=FAIL'; fi
    printf 'test_exit_code=%s\n' "$result"
} >"$temporary"
chmod 600 "$temporary"
mv "$temporary" "$evidence"
trap - EXIT HUP INT TERM
exit "$result"
