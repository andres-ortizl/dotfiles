#!/bin/sh
set -eu

scripts_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
homeserver_dir=${1:-$(dirname "$scripts_dir")}

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

compose=$homeserver_dir/docker-compose.yml
pihole_config=$homeserver_dir/config/pihole
repo_root=$(git -C "$homeserver_dir" rev-parse --show-toplevel 2>/dev/null) \
    || fail 'homeserver directory is not inside a git repository'
runtime_path=${pihole_config#"$repo_root"/}/etc-pihole

[ "$#" -le 1 ] || fail 'usage: test-pihole-config.sh [HOMESERVER_DIR]'
assert_once() {
    expected=$1
    count=$(grep -Fxc -- "$expected" "$compose" || true)
    [ "$count" -eq 1 ] || fail "expected exactly once: $expected"
}

literal_dollar='$'
assert_once "      - FTLCONF_webserver_api_password=${literal_dollar}{PIHOLE_PASSWORD:?set in .env}"
assert_once "      - FTLCONF_dns_upstreams=${literal_dollar}{PIHOLE_DNS:-1.1.1.1;1.0.0.1}"
assert_once '      - FTLCONF_dns_listeningMode=ALL'
assert_once '      - FTLCONF_dns_dnssec=true'
assert_once '      - FTLCONF_webserver_interface_theme=default-dark'
assert_once "      - FTLCONF_webserver_domain=pihole.${literal_dollar}{DOMAIN:?set DOMAIN=n33lab.com}"
assert_once '      - FTLCONF_misc_dnsmasq_lines=address=/n33lab.com/192.168.1.33'
assert_once '      - "192.168.1.33:53:53/tcp"'
assert_once '      - "192.168.1.33:53:53/udp"'

if grep -Eq '^[[:space:]]*-[[:space:]]*(WEBPASSWORD|PIHOLE_DNS_|DNSMASQ_LISTENING|DNSSEC|WEBTHEME|PIHOLE_DOMAIN|VIRTUAL_HOST)=' "$compose"; then
    fail 'removed Pi-hole v5 environment variable remains active'
fi
if grep -R -En 'lab\.lan|192\.168\.1\.193' "$compose" "$pihole_config" >/dev/null; then
    fail 'retired Pi-hole DNS state remains active'
fi
if grep -Fq './config/pihole/etc-dnsmasq.d:/etc/dnsmasq.d' "$compose"; then
    fail 'obsolete dnsmasq.d mount remains active'
fi
[ ! -e "$pihole_config/etc-dnsmasq.d/02-lab.conf" ] || fail 'obsolete 02-lab.conf remains tracked'
ignore_probe="$homeserver_dir/config/pihole/etc-pihole/.runtime-ignore-probe"
: >"$ignore_probe"
git -C "$repo_root" check-ignore -q "$ignore_probe" \
    || fail 'Pi-hole runtime directory is not ignored'
rm -f "$ignore_probe"
tracked_runtime=$(git -C "$repo_root" ls-files -- "$runtime_path" | while IFS= read -r path; do
    [ -e "$repo_root/$path" ] && printf '%s\n' "$path"
done)
[ -z "$tracked_runtime" ] || fail 'Pi-hole runtime files remain tracked'

dns_bindings=$(grep -Ec '^[[:space:]]*-[[:space:]]*"[^" ]*53:53/(tcp|udp)"' "$compose" || true)
[ "$dns_bindings" -eq 2 ] || fail 'DNS must have exactly one explicit TCP and UDP binding'

printf '%s\n' 'pihole_config_status=PASS'
