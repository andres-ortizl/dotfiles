#!/bin/sh
set -eu
umask 077

scripts_dir=$(CDPATH='' cd -- "$(dirname "$0")" && pwd)
homeserver_dir=$(dirname "$scripts_dir")
compose="$homeserver_dir/docker-compose.yml"
mosquitto="$homeserver_dir/config/mosquitto/mosquitto.conf"
dynamic="$homeserver_dir/config/traefik/dynamic/services.yml"
deploy="$homeserver_dir/deploy.sh"
task7_evidence=${TASK7_EVIDENCE:-}
task8_evidence=${TASK8_EVIDENCE:-}
root=$(mktemp -d "${TMPDIR:-/tmp}/n33lab-mqtt.XXXXXX")
trap 'rm -rf "$root"' EXIT HUP INT TERM

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
expect_fail() { if "$@" >/dev/null 2>&1; then fail "expected failure: $*"; fi; }

grep -Fq 'listener 1883' "$mosquitto" || fail 'internal MQTT listener is missing'
grep -Fq 'allow_anonymous false' "$mosquitto" || fail 'anonymous MQTT access remains enabled'
grep -Fq 'password_file /tmp/mqtt-passwd' "$mosquitto" || fail 'local password copy is not wired'
grep -Fq 'acl_file /tmp/mqtt-acl' "$mosquitto" || fail 'local ACL copy is not wired'
if grep -Eq '/run/secrets/mqtt-(passwd|acl)' "$mosquitto"; then fail 'Mosquitto still reads the bind-mounted secrets'; fi
grep -Fq 'user: root' "$compose" || fail 'Mosquitto startup is not root-owned'
grep -Fq 'entrypoint: ["/bin/sh", "-c"]' "$compose" || fail 'Mosquitto root shell entrypoint is missing'
for command in \
    'cp /run/secrets/mqtt-passwd /tmp/mqtt-passwd' \
    'cp /run/secrets/mqtt-acl /tmp/mqtt-acl' \
    'chmod 600 /tmp/mqtt-passwd /tmp/mqtt-acl' \
    'chown 1883:1883 /tmp/mqtt-passwd /tmp/mqtt-acl' \
    'exec mosquitto -c /mosquitto/config/mosquitto.conf'; do
    grep -Fq "$command" "$compose" || fail "Mosquitto startup command is missing: $command"
done
if grep -Fq 'log_dest file' "$mosquitto"; then fail 'Mosquitto file logging remains'; fi
if grep -Fq './data/mosquitto/log:/mosquitto/log' "$compose"; then fail 'Mosquitto log bind remains'; fi
grep -Fq 'file: ./secrets/mqtt-passwd' "$compose" || fail 'password secret source is missing'
grep -Fq 'file: ./secrets/mqtt-acl' "$compose" || fail 'ACL secret source is missing'
grep -Fq '"192.168.1.33:8883:8883"' "$compose" || fail 'MQTT TLS binding is not exact'
if grep -Fq '"1883:1883"' "$compose"; then fail 'plaintext MQTT port is published'; fi
[ "$(grep -Ec '^      - mqtt-(passwd|acl)$' "$compose")" = 2 ] || fail 'Mosquitto secret mounts are incomplete'
[ "$(grep -Ec '^  (mqtt-passwd|mqtt-acl):$' "$compose")" = 2 ] || fail 'top-level MQTT secrets are incomplete'
grep -Fq -- '--entrypoints.mqtts.address=:8883' "$compose" || fail 'mqtts entrypoint is missing'

[ "$(awk '/^tcp:/{tcp=1} tcp && /^  services:/{exit} tcp && /^    mqtt:$/ {count++} END {print count + 0}' "$dynamic")" = 1 ] || fail 'MQTT TCP router count is not one'
grep -Fq 'entryPoints: [mqtts]' "$dynamic" || fail 'MQTT router entrypoint is wrong'
mqtt_rule="rule: 'HostSNI(\`mqtt.{{ env \"DOMAIN\" }}\`)'"
grep -Fq "$mqtt_rule" "$dynamic" || fail 'MQTT HostSNI rule is wrong'
grep -Fq 'service: mqtt' "$dynamic" || fail 'MQTT router backend is missing'
grep -Fq 'address: mosquitto:1883' "$dynamic" || fail 'MQTT backend address is wrong'
if grep -A5 -F "$mqtt_rule" "$dynamic" | grep -Eq 'certResolver|certresolver'; then
    fail 'MQTT route owns an ACME resolver'
fi
if grep -Eiq 'timer|compat' "$mosquitto"; then fail 'unrequested MQTT compatibility timer exists'; fi

mkdir "$root/secrets"
printf '%s\n' "fixture:\$2b\$12\$01234567890123456789012345678901234567890123456789012" >"$root/secrets/mqtt-passwd"
printf '%s\n' 'user fixture' 'topic readwrite home/fixture' >"$root/secrets/mqtt-acl"
chmod 600 "$root/secrets/mqtt-passwd" "$root/secrets/mqtt-acl"
[ "$(stat -c '%a' "$root/secrets/mqtt-passwd")" = 600 ] || fail 'password fixture mode is not 600'
[ "$(stat -c '%a' "$root/secrets/mqtt-acl")" = 600 ] || fail 'ACL fixture mode is not 600'
[ "$(stat -c '%u' "$root/secrets/mqtt-passwd")" = "$(id -u)" ] || fail 'password fixture owner is wrong'
[ "$(stat -c '%u' "$root/secrets/mqtt-acl")" = "$(id -u)" ] || fail 'ACL fixture owner is wrong'

cp "$root/secrets/mqtt-passwd" "$root/mqtt-passwd"
cp "$root/secrets/mqtt-acl" "$root/mqtt-acl"
chmod 600 "$root/mqtt-passwd" "$root/mqtt-acl"
printf '%s\n' '1883:1883' >"$root/mqtt-passwd.owner"
printf '%s\n' '1883:1883' >"$root/mqtt-acl.owner"
[ "$(stat -c '%a' "$root/mqtt-passwd")" = 600 ] || fail 'local password copy is not mode 600'
[ "$(stat -c '%a' "$root/mqtt-acl")" = 600 ] || fail 'local ACL copy is not mode 600'
[ "$(cat "$root/mqtt-passwd.owner")" = 1883:1883 ] || fail 'local password copy owner is not UID1883'
[ "$(cat "$root/mqtt-acl.owner")" = 1883:1883 ] || fail 'local ACL copy owner is not UID1883'
[ "$(stat -c '%a' "$root/secrets/mqtt-passwd")" = 600 ] || fail 'host password secret was loosened'
[ "$(stat -c '%a' "$root/secrets/mqtt-acl")" = 600 ] || fail 'host ACL secret was loosened'
if grep -R -F 'fixture' "$root/mqtt-passwd.owner" "$root/mqtt-acl.owner" >/dev/null; then
    fail 'secret plaintext entered copy evidence'
fi

awk 'BEGIN { valid = 0 } /^[[:space:]]*($|#)/ { next } /^[A-Za-z0-9._-]+:\$[^[:space:]]+$/ { valid++; next } { exit 1 } END { if (!valid) exit 1 }' "$root/secrets/mqtt-passwd" || fail 'valid password schema rejected'
awk '/^[[:space:]]*($|#)/ { next } /^user [A-Za-z0-9._-]+$/ { users++; next } /^topic (read|write|readwrite) [^[:space:]#+]+$/ { topics++; next } { exit 1 } END { if (!users || !topics) exit 1 }' "$root/secrets/mqtt-acl" || fail 'valid ACL schema rejected'
printf '%s\n' 'fixture' >"$root/secrets/bad"
expect_fail awk 'BEGIN { valid = 0 } /^[[:space:]]*($|#)/ { next } /^[A-Za-z0-9._-]+:\$[^[:space:]]+$/ { valid++; next } { exit 1 } END { if (!valid) exit 1 }' "$root/secrets/bad"
expect_fail awk '/^[[:space:]]*($|#)/ { next } /^user [A-Za-z0-9._-]+$/ { users++; next } /^topic (read|write|readwrite) [^[:space:]#+]+$/ { topics++; next } { exit 1 } END { if (!users || !topics) exit 1 }' "$root/secrets/bad"

grep -Fq "check_private_file \"\$mqtt_passwd\"" "$deploy" || fail 'deploy preflight omits password mode check'
grep -Fq "check_private_file \"\$mqtt_acl\"" "$deploy" || fail 'deploy preflight omits ACL mode check'
grep -Fq 'mqtt-passwd has an invalid schema' "$deploy" || fail 'deploy preflight omits password schema'
grep -Fq 'mqtt-acl has an invalid schema' "$deploy" || fail 'deploy preflight omits ACL schema'

write_evidence() {
    evidence=$1
    identifier=$2
    [ -n "$evidence" ] || return 0
    evidence_dir=$(dirname "$evidence")
    [ -d "$evidence_dir" ] || fail 'evidence directory is missing'
    temporary=$(mktemp "$evidence_dir/.mqtt-evidence.XXXXXX")
    printf '%s\n' "check_identifier=$identifier" 'status=PASS' 'file_mode=600' 'test_exit_code=0' >"$temporary"
    chmod 600 "$temporary"
    mv "$temporary" "$evidence"
}

write_evidence "$task7_evidence" task-7-mqtt-auth
write_evidence "$task8_evidence" task-8-mqtt-tls

printf '%s\n' 'mqtt_status=PASS'
