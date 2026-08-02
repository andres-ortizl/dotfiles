#!/bin/sh
set -eu

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s [--homeserver-dir DIR] [--matrix FILE]\n' "$0"
}

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
homeserver_dir=$(dirname "$script_dir")
matrix="$script_dir/hostname-matrix.tsv"

while [ "$#" -gt 0 ]; do
  case $1 in
    --homeserver-dir)
      [ "$#" -ge 2 ] || fail 'missing value for --homeserver-dir'
      homeserver_dir=$2
      shift 2
      ;;
    --matrix)
      [ "$#" -ge 2 ] || fail 'missing value for --matrix'
      matrix=$2
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *) fail "unknown option: $1" ;;
  esac
done

compose="$homeserver_dir/docker-compose.yml"
glance="$homeserver_dir/config/glance/glance.yml"
dynamic_dir="$homeserver_dir/config/traefik/dynamic"
migration="$homeserver_dir/forgejo-migrate.sh"
env_example="$homeserver_dir/.env.example"
deploy="$homeserver_dir/deploy.sh"
recovery="$homeserver_dir/recover-env.sh"

for file in "$matrix" "$compose" "$glance" "$migration" "$env_example" "$deploy" "$recovery" \
  "$dynamic_dir/homeassistant.yml" "$dynamic_dir/esphome.yml" "$dynamic_dir/musicassistant.yml"; do
  [ -f "$file" ] && [ ! -L "$file" ] || fail "required regular file missing: $file"
done

expected_matrix=$(cat <<'EOF'
n33lab.com	http	glance	glance:8080	80,443=traefik
traefik.n33lab.com	http	dashboard	api@internal	9090=retained
docker.n33lab.com	http	dockhand	dockhand:3000	none
pihole.n33lab.com	http	pihole	pihole:80	3333=retained;53/tcp,53/udp=dns
qbittorrent.n33lab.com	http	qbittorrent	qbittorrent:8080	6881/tcp,6881/udp=bittorrent
immich.n33lab.com	http	immich	immich-server:2283	none
chat.n33lab.com	http	openwebui	openwebui:8080	none
excalidraw.n33lab.com	http	excalidraw	excalidraw:80	none
uptime.n33lab.com	http	uptime-kuma	uptime-kuma:3001	none
logs.n33lab.com	http	dozzle	dozzle:8080	none
files.n33lab.com	http	filebrowser	filebrowser:80	none
backup.n33lab.com	http	backrest	backrest:9898	none
ha.n33lab.com	http	homeassistant	host.docker.internal:8123	8123=retained
ha-esphome.n33lab.com	http	esphome	host.docker.internal:6052	6052=retained
ha-music.n33lab.com	http	musicassistant	host.docker.internal:8095	8095=retained;8097=stream
ha-flows.n33lab.com	http	node-red	node-red:1880	none
git.n33lab.com	http	forgejo	forgejo:3000	222=ssh
mqtt.n33lab.com	reserved	mqtt	mosquitto:1883	8883=reserved-tcp-tls;1883=retained-until-task-8
nas.local	native	ugreen	nas.local:9443	9999=redirect-to-9443;80,443=disabled
EOF
)
[ "$(cat "$matrix")" = "$expected_matrix" ] || fail 'hostname matrix differs from the approved matrix'
awk -F '\t' 'NF != 5 || $1 == "" || $2 == "" || $3 == "" || $4 == "" || $5 == "" { exit 1 } !seen[$1]++ { next } { exit 1 }' "$matrix" \
  || fail 'hostname matrix is malformed or contains duplicate hostnames'
[ "$(awk -F '\t' '$2 == "http" { count++ } END { print count + 0 }' "$matrix")" -eq 17 ] \
  || fail 'hostname matrix must contain the apex and 16 HTTP subdomains'
[ "$(awk -F '\t' '$2 == "reserved" && $1 == "mqtt.n33lab.com" { count++ } END { print count + 0 }' "$matrix")" -eq 1 ] \
  || fail 'MQTT reservation is missing'

count_fixed() {
  expected=$1
  needle=$2
  shift 2
  actual=$(grep -F -h -c "$needle" "$@" | awk '{ total += $1 } END { print total + 0 }')
  [ "$actual" -eq "$expected" ] || fail "expected $expected occurrence(s), found $actual: $needle"
}

dollar='$'
domain="${dollar}{DOMAIN:?set DOMAIN=n33lab.com}"
count_fixed 2 "DOMAIN=$domain" "$compose"

verify_compose_route() {
  hostname=$1
  router=$2
  backend=$3
  host_prefix=${hostname%.n33lab.com}
  if [ "$hostname" = n33lab.com ]; then
    host_rule="$domain"
  else
    host_rule="$host_prefix.$domain"
  fi
  count_fixed 1 "traefik.http.routers.$router.rule=Host(\`$host_rule\`)" "$compose"
  count_fixed 1 "traefik.http.routers.$router-secure.rule=Host(\`$host_rule\`)" "$compose"
  count_fixed 1 "traefik.http.routers.$router-secure.tls=true" "$compose"
  case $backend in
    api@internal)
      count_fixed 2 'service=api@internal' "$compose"
      ;;
    *)
      port=${backend##*:}
      count_fixed 1 "traefik.http.services.$router.loadbalancer.server.port=$port" "$compose"
      ;;
  esac
}

verify_compose_route n33lab.com glance glance:8080
verify_compose_route traefik.n33lab.com dashboard api@internal
verify_compose_route docker.n33lab.com dockhand dockhand:3000
verify_compose_route pihole.n33lab.com pihole pihole:80
verify_compose_route qbittorrent.n33lab.com qbittorrent qbittorrent:8080
verify_compose_route immich.n33lab.com immich immich-server:2283
verify_compose_route chat.n33lab.com openwebui openwebui:8080
verify_compose_route excalidraw.n33lab.com excalidraw excalidraw:80
verify_compose_route uptime.n33lab.com uptime-kuma uptime-kuma:3001
verify_compose_route logs.n33lab.com dozzle dozzle:8080
verify_compose_route files.n33lab.com filebrowser filebrowser:80
verify_compose_route backup.n33lab.com backrest backrest:9898
verify_compose_route ha-flows.n33lab.com node-red node-red:1880
verify_compose_route git.n33lab.com forgejo forgejo:3000

verify_dynamic_route() {
  hostname=$1
  router=$2
  backend=$3
  file=$4
  prefix=${hostname%.n33lab.com}
  count_fixed 2 "rule: 'Host(\`$prefix.{{ env \"DOMAIN\" }}\`)'" "$file"
  count_fixed 1 "url: \"http://$backend\"" "$file"
  count_fixed 2 "service: $router" "$file"
}

verify_dynamic_route ha.n33lab.com homeassistant host.docker.internal:8123 "$dynamic_dir/homeassistant.yml"
verify_dynamic_route ha-esphome.n33lab.com esphome host.docker.internal:6052 "$dynamic_dir/esphome.yml"
verify_dynamic_route ha-music.n33lab.com musicassistant host.docker.internal:8095 "$dynamic_dir/musicassistant.yml"

host_rule_count=$(grep -F -h -c 'Host(`' "$compose" "$dynamic_dir"/*.yml | awk '{ total += $1 } END { print total + 0 }')
[ "$host_rule_count" -eq 34 ] || fail "expected 34 HTTP Host rules, found $host_rule_count"

for prefix in immich qbittorrent files chat excalidraw pihole traefik docker logs uptime backup ha ha-esphome ha-music ha-flows; do
  count_fixed 1 "url: http://$prefix.\${DOMAIN}" "$glance"
done
count_fixed 1 "homepage.href=http://pihole.${dollar}{DOMAIN:?set DOMAIN=n33lab.com}:3333/admin" "$compose"
count_fixed 1 "FORGEJO__server__DOMAIN=git.${dollar}{DOMAIN:?set DOMAIN=n33lab.com}" "$compose"
count_fixed 1 "FORGEJO__server__ROOT_URL=https://git.${dollar}{DOMAIN:?set DOMAIN=n33lab.com}/" "$compose"
count_fixed 1 "FORGEJO__server__SSH_DOMAIN=git.${dollar}{DOMAIN:?set DOMAIN=n33lab.com}" "$compose"
count_fixed 1 "FORGEJO_URL=${dollar}{1:-https://git.n33lab.com}" "$migration"

for published_port in '"80:80"' '"443:443"' '"9090:8080"' \
  '"192.168.1.33:53:53/tcp"' '"192.168.1.33:53:53/udp"' '"3333:80"' \
  '"6881:6881"' '"6881:6881/udp"' '"1883:1883"' '"222:22"'; do
  count_fixed 1 "$published_port" "$compose"
done
[ "$(grep -c '^[[:space:]]*ports:$' "$compose")" -eq 5 ] || fail 'unexpected direct-port publication block'

if grep -E -n 'lab\.lan|nasito\.local|192\.168\.1\.193|\$\{DOMAIN:-localhost\}|(^|[^A-Za-z0-9-])home\.\$\{DOMAIN' \
  "$compose" "$env_example" "$glance" "$dynamic_dir/homeassistant.yml" "$dynamic_dir/esphome.yml" \
  "$dynamic_dir/musicassistant.yml" "$migration" "$deploy" "$recovery" >/dev/null; then
  fail 'active tracked source contains a legacy hostname, address, or domain fallback'
fi

printf '%s\n' 'hostname_matrix_status=PASS'
