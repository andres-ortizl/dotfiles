#!/bin/sh
set -eu

scripts_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
homeserver_dir=${1:-$(dirname "$scripts_dir")}
compose=$homeserver_dir/docker-compose.yml
pihole_config=$homeserver_dir/config/pihole

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
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

dns_bindings=$(grep -Ec '^[[:space:]]*-[[:space:]]*"[^" ]*53:53/(tcp|udp)"' "$compose" || true)
[ "$dns_bindings" -eq 2 ] || fail 'DNS must have exactly one explicit TCP and UDP binding'

printf '%s\n' 'pihole_config_status=PASS'
