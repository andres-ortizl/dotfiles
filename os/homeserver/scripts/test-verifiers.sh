#!/bin/sh
set -eu
umask 077

scripts_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
root=$(mktemp -d /tmp/n33lab-verifiers.XXXXXX)
trap 'rm -rf "$root"' EXIT
trap 'exit 1' HUP INT TERM

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
expect_ok() { "$@" >/dev/null 2>&1 || fail "expected success: $*"; }
expect_fail() { if "$@" >/dev/null 2>&1; then fail "expected failure: $*"; fi; }
assert_mode() { [ "$(stat -c %a "$1")" = 600 ] || fail "wrong mode: $1"; }
assert_schema() {
    file=$1
    expected=$2
    actual=$(cut -d= -f1 "$file" | sort | tr '\n' ' ')
    [ "$actual" = "$expected" ] || fail "schema mismatch: $file"
}
assert_allowlisted() {
    if grep -Evq '^(check_identifier=[A-Za-z0-9-]+|timestamp_utc=[0-9TZ:+-]+|execution_node=(workstation|nas|external)|git_commit=[0-9A-Za-z._-]+|changed_path=[A-Za-z0-9_./*-]+|status=[A-Za-z_]+|image_pin_check=PASS|file_mode=[0-7]+|listener_(address|port|protocol|probe_state)=[A-Za-z0-9:._/-]+|test_exit_code=[0-9]+|error_code=[A-Za-z0-9._-]+)$' "$1"; then
        fail "non-allowlisted evidence field: $1"
    fi
}

mkdir -m 700 "$root/bin" "$root/evidence" "$root/refs" "$root/remote" "$root/output"
cat >"$root/bin/git" <<'EOF'
#!/bin/sh
case $1 in
    cat-file) exit 0 ;;
    diff)
        case " $* " in *' --name-only '*) printf '%s\n' 'os/homeserver/scripts/test-verifiers.sh' ;; esac
        exit 0
        ;;
    grep)
        case "$*" in *'222|6881|8097|9443|9999'*) exit 0 ;; *) exit 1 ;; esac
        ;;
esac
exit 0
EOF
cat >"$root/bin/docker" <<'EOF'
#!/bin/sh
if [ "${SLEEP_DOCKER:-0}" = 1 ]; then sleep 2; fi
exit 0
EOF
cat >"$root/bin/scp" <<'EOF'
#!/bin/sh
source_path=
destination=
for argument do source_path=$destination; destination=$argument; done
file=${source_path##*/}
cp "$STUB_REMOTE_ROOT/$file" "$destination"
EOF
chmod 755 "$root/bin/git" "$root/bin/docker" "$root/bin/scp"
test_path="$root/bin:$PATH"

task_files='task-1-deploy-preflight.txt task-2-pihole-dns.txt task-3-hostname-matrix.txt task-4-acme-staging.txt task-5-https-auth.txt task-6-production-cutover.txt task-7-mqtt-auth.txt task-8-mqtt-tls.txt task-9-docker-socket-proxy.txt task-10-controlled-updates.txt task-11-firewall.txt task-12-legacy-retirement.txt task-13-end-to-end.txt'
for file in $task_files; do printf '%s\n' 'status=PASS' >"$root/evidence/$file"; chmod 600 "$root/evidence/$file"; done
assert_mode "$root/evidence/task-10-controlled-updates.txt"
assert_allowlisted "$root/evidence/task-10-controlled-updates.txt"
cat >"$root/plan.md" <<'EOF'
task-1-deploy-preflight.txt task-2-pihole-dns.txt task-3-hostname-matrix.txt task-4-acme-staging.txt
task-5-https-auth.txt task-6-production-cutover.txt task-7-mqtt-auth.txt task-8-mqtt-tls.txt
task-9-docker-socket-proxy.txt task-10-controlled-updates.txt task-11-firewall.txt task-12-legacy-retirement.txt task-13-end-to-end.txt
n33lab.com traefik.n33lab.com docker.n33lab.com pihole.n33lab.com qbittorrent.n33lab.com immich.n33lab.com
chat.n33lab.com excalidraw.n33lab.com uptime.n33lab.com logs.n33lab.com files.n33lab.com backup.n33lab.com
ha.n33lab.com ha-esphome.n33lab.com ha-music.n33lab.com ha-flows.n33lab.com git.n33lab.com mqtt.n33lab.com
22,53,80,443,222,1883,3333,6052,6881,8095,8097,8123,8883,9090,9443,9999
53,67,68,6881
DNS/Pi-hole Traefik/ACME MQTT Docker socket proxy Watchtower/update Firewall UGREEN URLs/config
EOF
cat >"$root/compose.yml" <<'EOF'
services:
  fixture:
    image: fixture@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
EOF

sentinel=TASK1B_SECRET_SENTINEL
for name in basic ha forgejo esphome music mqtt admin wan ipv6 public; do printf '%s\n' "$sentinel" >"$root/refs/$name"; chmod 600 "$root/refs/$name"; done
mkdir -m 700 "$root/checks" "$root/empty-checks"
checks='dns tls http auth websocket mqtt ports discovery ota playback forgejo pihole docker-api dhcp ssh ugreen'
for check in $checks; do printf '%s\n' '#!/bin/sh' 'exit 0' >"$root/checks/$check-check"; chmod 700 "$root/checks/$check-check"; done
printf '%s\n' '#!/bin/sh' 'exit 0' >"$root/probe-pass"
chmod 700 "$root/probe-pass"
cat >"$root/qa-manifest.env" <<EOF
MODE=reference
BASIC_AUTH_CREDENTIALS_FILE=$root/refs/basic
HOME_ASSISTANT_CREDENTIALS_FILE=$root/refs/ha
FORGEJO_TOKEN_FILE=$root/refs/forgejo
ESPHOME_DEVICE_FILE=$root/refs/esphome
MUSIC_ASSISTANT_PLAYER_FILE=$root/refs/music
MQTT_CLIENT_FILES_FILE=$root/refs/mqtt
ADMIN_IPV4_SET_FILE=$root/refs/admin
CHECKS_DIR=$root/checks
EOF
cat >"$root/qa-external.env" <<EOF
MODE=reference
WAN_IPV4_FILE=$root/refs/wan
NAS_GLOBAL_IPV6_FILE=$root/refs/ipv6
PUBLIC_DNS_RESOLVERS_FILE=$root/refs/public
EXTERNAL_PROBE_COMMAND_FILE=$root/probe-pass
EOF
cat >"$root/qa-worker.env" <<'EOF'
NAS_ENDPOINT=evidence@nas
EXTERNAL_ENDPOINT=evidence@external
EOF
chmod 600 "$root/qa-manifest.env" "$root/qa-external.env" "$root/qa-worker.env"
assert_schema "$root/qa-manifest.env" 'ADMIN_IPV4_SET_FILE BASIC_AUTH_CREDENTIALS_FILE CHECKS_DIR ESPHOME_DEVICE_FILE FORGEJO_TOKEN_FILE HOME_ASSISTANT_CREDENTIALS_FILE MODE MQTT_CLIENT_FILES_FILE MUSIC_ASSISTANT_PLAYER_FILE '
assert_schema "$root/qa-external.env" 'EXTERNAL_PROBE_COMMAND_FILE MODE NAS_GLOBAL_IPV6_FILE PUBLIC_DNS_RESOLVERS_FILE WAN_IPV4_FILE '
assert_schema "$root/qa-worker.env" 'EXTERNAL_ENDPOINT NAS_ENDPOINT '

tcp='22,53,80,443,222,1883,3333,6052,6881,8095,8097,8123,8883,9090,9443,9999'
udp='53,67,68,6881'
[ "$(printf '%s\n' "$tcp" | awk -F, '{ print NF }')" = 16 ] || fail 'TCP matrix count is not 16'

for script in verify-plan-compliance.sh verify-config.sh verify-runtime.sh verify-external.sh verify-scope.sh collect-evidence.sh; do
    expect_ok "$scripts_dir/$script" --help
    expect_fail "$scripts_dir/$script" --unknown
done
mkdir -m 700 "$root/no-tools"
PATH=$root/no-tools expect_fail /bin/sh "$scripts_dir/verify-plan-compliance.sh" --base base --plan "$root/plan.md" --evidence "$root/evidence/no-tools-plan.txt"
PATH=$root/no-tools expect_fail /bin/sh "$scripts_dir/verify-config.sh" --base base --compose "$root/compose.yml" --fixtures-dir "$root/no-tools-fixtures" --evidence "$root/evidence/no-tools-config.txt"
PATH=$root/no-tools expect_fail /bin/sh "$scripts_dir/verify-runtime.sh" --nas-ip 192.168.1.33 --domain n33lab.com --qa-manifest "$root/qa-manifest.env" --output-dir "$root/output/no-tools-runtime"
PATH=$root/no-tools expect_fail /bin/sh "$scripts_dir/verify-external.sh" --qa-manifest "$root/qa-external.env" --tcp-ports "$tcp" --udp-ports "$udp" --output-dir "$root/output/no-tools-external"
PATH=$root/no-tools expect_fail /bin/sh "$scripts_dir/verify-scope.sh" --base base --scope "$root/plan.md" --evidence "$root/evidence/no-tools-scope.txt"
PATH=$root/no-tools expect_fail /bin/sh "$scripts_dir/collect-evidence.sh" --manifest "$root/qa-worker.env" --round round --destination "$root/evidence"

PATH=$test_path expect_ok "$scripts_dir/verify-plan-compliance.sh" --base base --plan "$root/plan.md" --evidence "$root/evidence/plan.txt"
PATH=$test_path expect_ok "$scripts_dir/verify-config.sh" --base base --compose "$root/compose.yml" --fixtures-dir "$root/config-fixtures" --evidence "$root/evidence/config.txt"
expect_fail "$scripts_dir/verify-runtime.sh" --nas-ip 192.168.1.33 --domain n33lab.com --qa-manifest "$root/qa-manifest.env" --output-dir "$root/output/nas-reference"
expect_fail "$scripts_dir/verify-external.sh" --qa-manifest "$root/qa-external.env" --tcp-ports "$tcp" --udp-ports "$udp" --output-dir "$root/output/external-reference"
grep -q '^status=reference_validated$' "$root/output/nas-reference/runtime.txt" || fail 'runtime reference mode did not record blocked validation'
grep -q '^status=reference_validated$' "$root/output/external-reference/external.txt" || fail 'external reference mode did not record blocked validation'
sed 's/MODE=reference/MODE=execute/' "$root/qa-manifest.env" >"$root/qa-manifest-execute.env"
sed 's/MODE=reference/MODE=execute/' "$root/qa-external.env" >"$root/qa-external-execute.env"
chmod 600 "$root/qa-manifest-execute.env" "$root/qa-external-execute.env"
expect_ok "$scripts_dir/verify-runtime.sh" --nas-ip 192.168.1.33 --domain n33lab.com --qa-manifest "$root/qa-manifest-execute.env" --output-dir "$root/output/nas"
expect_ok "$scripts_dir/verify-external.sh" --qa-manifest "$root/qa-external-execute.env" --tcp-ports "$tcp" --udp-ports "$udp" --output-dir "$root/output/external"
[ "$(grep -c '^check_identifier=runtime-' "$root/output/nas/runtime.txt")" = 16 ] || fail 'not every runtime check was dispatched'
[ "$(grep -c '^status=PASS$' "$root/output/nas/runtime.txt")" = 17 ] || fail 'runtime execute evidence contains a non-pass status'
grep -q '^status=PASS$' "$root/output/external/external.txt" || fail 'external execute probe did not pass'
PATH=$test_path expect_ok "$scripts_dir/verify-scope.sh" --base base --scope "$root/plan.md" --evidence "$root/evidence/scope.txt"
cp "$root/output/nas/runtime.txt" "$root/output/nas/runtime.txt.sha256" "$root/output/external/external.txt" "$root/output/external/external.txt.sha256" "$root/remote/"
mkdir -m 700 "$root/evidence/collected"
STUB_REMOTE_ROOT=$root/remote PATH=$test_path expect_ok "$scripts_dir/collect-evidence.sh" --manifest "$root/qa-worker.env" --round round-1 --destination "$root/evidence/collected"

for evidence in "$root/evidence/plan.txt" "$root/evidence/config.txt" "$root/evidence/scope.txt" "$root/output/nas/runtime.txt" "$root/output/nas/runtime.txt.sha256" "$root/output/external/external.txt" "$root/output/external/external.txt.sha256" "$root/evidence/collected/runtime.txt" "$root/evidence/collected/external.txt"; do assert_mode "$evidence"; done
for evidence in "$root/evidence/plan.txt" "$root/evidence/config.txt" "$root/evidence/scope.txt" "$root/output/nas/runtime.txt" "$root/output/external/external.txt" "$root/evidence/collected/runtime.txt" "$root/evidence/collected/external.txt"; do assert_allowlisted "$evidence"; done
grep -R "$sentinel" "$root/evidence" "$root/output" >/dev/null 2>&1 && fail 'secret sentinel appeared in evidence'

expect_fail "$scripts_dir/verify-plan-compliance.sh" --base base --plan "$root/missing" --evidence "$root/evidence/missing.txt"
expect_fail "$scripts_dir/verify-config.sh" --base base --compose "$root/missing" --fixtures-dir "$root/missing-fixtures" --evidence "$root/evidence/missing-config.txt"
expect_fail "$scripts_dir/verify-runtime.sh" --nas-ip 192.168.1.33 --domain n33lab.com --qa-manifest "$root/missing" --output-dir "$root/output/missing"
expect_fail "$scripts_dir/verify-external.sh" --qa-manifest "$root/missing" --tcp-ports "$tcp" --udp-ports "$udp" --output-dir "$root/output/missing"
expect_fail "$scripts_dir/verify-scope.sh" --base base --scope "$root/missing" --evidence "$root/evidence/missing-scope.txt"
expect_fail "$scripts_dir/collect-evidence.sh" --manifest "$root/missing" --round round --destination "$root/evidence"

chmod 644 "$root/qa-manifest.env"
expect_fail "$scripts_dir/verify-runtime.sh" --nas-ip 192.168.1.33 --domain n33lab.com --qa-manifest "$root/qa-manifest.env" --output-dir "$root/output/wrong-mode"
chmod 600 "$root/qa-manifest.env"
chmod 644 "$root/qa-external.env"
expect_fail "$scripts_dir/verify-external.sh" --qa-manifest "$root/qa-external.env" --tcp-ports "$tcp" --udp-ports "$udp" --output-dir "$root/output/wrong-external-mode"
chmod 600 "$root/qa-external.env"
chmod 644 "$root/qa-worker.env"
expect_fail "$scripts_dir/collect-evidence.sh" --manifest "$root/qa-worker.env" --round round --destination "$root/evidence"
chmod 600 "$root/qa-worker.env"
ln -s "$root/qa-manifest.env" "$root/runtime-link.env"
expect_fail "$scripts_dir/verify-runtime.sh" --nas-ip 192.168.1.33 --domain n33lab.com --qa-manifest "$root/runtime-link.env" --output-dir "$root/output/symlink"
expect_fail "$scripts_dir/collect-evidence.sh" --manifest "$root/qa-worker.env" --round ../escape --destination "$root/evidence"
mkdir -m 700 "$root/real-destination"
ln -s "$root/real-destination" "$root/symlink-destination"
expect_fail "$scripts_dir/collect-evidence.sh" --manifest "$root/qa-worker.env" --round round --destination "$root/symlink-destination"
expect_fail "$scripts_dir/verify-external.sh" --qa-manifest "$root/qa-external.env" --tcp-ports 22,443 --udp-ports "$udp" --output-dir "$root/output/wrong-ports"
printf '%s\n' 'MODE=reference' 'UNTRUSTED_TEXT=secret' >"$root/malformed.env"
chmod 600 "$root/malformed.env"
expect_fail "$scripts_dir/verify-runtime.sh" --nas-ip 192.168.1.33 --domain n33lab.com --qa-manifest "$root/malformed.env" --output-dir "$root/output/malformed"
grep -v '^CHECKS_DIR=' "$root/qa-manifest.env" >"$root/runtime-missing-key.env"
grep -v '^PUBLIC_DNS_RESOLVERS_FILE=' "$root/qa-external.env" >"$root/external-missing-key.env"
printf '%s\n' 'NAS_ENDPOINT=evidence@nas' 'EXTERNAL_ENDPOINT=evidence@external' 'EXTRA_ENDPOINT=evidence@extra' >"$root/worker-extra-key.env"
chmod 600 "$root/runtime-missing-key.env" "$root/external-missing-key.env" "$root/worker-extra-key.env"
expect_fail "$scripts_dir/verify-runtime.sh" --nas-ip 192.168.1.33 --domain n33lab.com --qa-manifest "$root/runtime-missing-key.env" --output-dir "$root/output/runtime-missing-key"
expect_fail "$scripts_dir/verify-external.sh" --qa-manifest "$root/external-missing-key.env" --tcp-ports "$tcp" --udp-ports "$udp" --output-dir "$root/output/external-missing-key"
expect_fail "$scripts_dir/collect-evidence.sh" --manifest "$root/worker-extra-key.env" --round round --destination "$root/evidence"

sed "s#MODE=reference#MODE=execute#; s#CHECKS_DIR=.*#CHECKS_DIR=$root/empty-checks#" "$root/qa-manifest.env" >"$root/runtime-execute.env"
sed 's#MODE=reference#MODE=execute#; s#EXTERNAL_PROBE_COMMAND_FILE=.*#EXTERNAL_PROBE_COMMAND_FILE=/missing#' "$root/qa-external.env" >"$root/external-execute.env"
chmod 600 "$root/runtime-execute.env" "$root/external-execute.env"
expect_fail "$scripts_dir/verify-runtime.sh" --nas-ip 192.168.1.33 --domain n33lab.com --qa-manifest "$root/runtime-execute.env" --output-dir "$root/output/runtime-blocked"
expect_fail "$scripts_dir/verify-external.sh" --qa-manifest "$root/external-execute.env" --tcp-ports "$tcp" --udp-ports "$udp" --output-dir "$root/output/external-blocked"
grep -q '^status=blocked$' "$root/output/runtime-blocked/runtime.txt" || fail 'runtime future check was not blocked'
grep -q '^status=blocked$' "$root/output/external-blocked/external.txt" || fail 'external future check was not blocked'

cat >"$root/probe" <<EOF
#!/bin/sh
printf '%s\n' 'status=PASS $sentinel'
exit 1
EOF
chmod 700 "$root/probe"
sed "s#MODE=reference#MODE=execute#; s#EXTERNAL_PROBE_COMMAND_FILE=.*#EXTERNAL_PROBE_COMMAND_FILE=$root/probe#" "$root/qa-external.env" >"$root/external-misleading.env"
chmod 600 "$root/external-misleading.env"
expect_fail "$scripts_dir/verify-external.sh" --qa-manifest "$root/external-misleading.env" --tcp-ports "$tcp" --udp-ports "$udp" --output-dir "$root/output/misleading"
grep -q "$sentinel" "$root/output/misleading/external.txt" && fail 'misleading probe output entered evidence'
cat >"$root/bin/timeout" <<'EOF'
#!/bin/sh
if [ "${1-}" = --version ]; then printf '%s\n' 'timeout (GNU coreutils) fixture'; exit 0; fi
exit 124
EOF
chmod 755 "$root/bin/timeout"
expect_fail env PATH="$test_path" "$scripts_dir/verify-external.sh" --qa-manifest "$root/external-misleading.env" --tcp-ports "$tcp" --udp-ports "$udp" --output-dir "$root/output/timeout"
grep -q 'test_exit_code=124' "$root/output/timeout/external.txt" || fail 'timeout was not recorded as failure'
rm "$root/bin/timeout"

mkdir -m 700 "$root/evidence/drift"
printf '%064d  runtime.txt\n' 0 >"$root/remote/runtime.txt.sha256"
chmod 600 "$root/remote/runtime.txt.sha256"
STUB_REMOTE_ROOT=$root/remote PATH=$test_path expect_fail "$scripts_dir/collect-evidence.sh" --manifest "$root/qa-worker.env" --round round-2 --destination "$root/evidence/drift"
cp "$root/output/nas/runtime.txt.sha256" "$root/remote/runtime.txt.sha256"

SLEEP_DOCKER=1 PATH=$test_path "$scripts_dir/verify-config.sh" --base base --compose "$root/compose.yml" --fixtures-dir "$root/interrupted-fixtures" --evidence "$root/evidence/interrupted.txt" >/dev/null 2>&1 &
process=$!
sleep 1
kill -TERM "$process" 2>/dev/null || true
wait "$process" 2>/dev/null && fail 'interrupted config verifier succeeded'
[ ! -e "$root/interrupted-fixtures" ] || fail 'interrupt cleanup left fixtures behind'

printf '%s\n' 'fixture_status=PASS'
