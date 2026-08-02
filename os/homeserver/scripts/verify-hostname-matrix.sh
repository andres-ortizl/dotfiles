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
image_pins="$script_dir/test-image-pins.sh"

for file in "$matrix" "$compose" "$glance" "$migration" "$env_example" "$deploy" "$recovery" "$image_pins" \
  "$dynamic_dir/homeassistant.yml" "$dynamic_dir/esphome.yml" "$dynamic_dir/musicassistant.yml"; do
  [ -f "$file" ] && [ ! -L "$file" ] || fail "required regular file missing: $file"
done

expected_matrix=$(cat <<'EOF'
n33lab.com	http	glance	glance:8080	80,443=traefik
traefik.n33lab.com	http	dashboard	api@internal	9090=disabled
docker.n33lab.com	http	dockhand	dockhand:3000	none
pihole.n33lab.com	http	pihole	pihole:80	53/tcp,53/udp=dns
qbittorrent.n33lab.com	http	qbittorrent	qbittorrent:8080	6881/tcp,6881/udp=bittorrent
immich.n33lab.com	http	immich	immich-server:2283	none
chat.n33lab.com	http	openwebui	openwebui:8080	none
excalidraw.n33lab.com	http	excalidraw	excalidraw:80	none
uptime.n33lab.com	http	gatus	gatus:8080	none
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

verify_dynamic_service() {
  router=$1
  backend=$2
  if [ "$backend" = api@internal ]; then
    count_fixed 1 'service: api@internal' "$dynamic_dir/services.yml"
  elif printf '%s\n' "$backend" | grep -q '^host\.docker\.internal:'; then
    file="$dynamic_dir/$router.yml"
    count_fixed 1 "service: $router" "$file"
    count_fixed 1 "url: \"http://$backend\"" "$file"
  else
    count_fixed 1 "service: $router" "$dynamic_dir/services.yml"
    count_fixed 1 "url: http://$backend" "$dynamic_dir/services.yml"
  fi
}

for route in \
  "n33lab.com glance glance:8080" "traefik.n33lab.com dashboard api@internal" \
  "docker.n33lab.com dockhand dockhand:3000" "pihole.n33lab.com pihole pihole:80" \
  "qbittorrent.n33lab.com qbittorrent qbittorrent:8080" "immich.n33lab.com immich immich-server:2283" \
  "chat.n33lab.com openwebui openwebui:8080" "excalidraw.n33lab.com excalidraw excalidraw:80" \
  "uptime.n33lab.com gatus gatus:8080" "logs.n33lab.com dozzle dozzle:8080" \
  "files.n33lab.com filebrowser filebrowser:80" "backup.n33lab.com backrest backrest:9898" \
  "ha-flows.n33lab.com node-red node-red:1880" "git.n33lab.com forgejo forgejo:3000"; do
  router=$(printf '%s\n' "$route" | cut -d' ' -f2)
  backend=$(printf '%s\n' "$route" | cut -d' ' -f3)
  verify_dynamic_service "$router" "$backend"
done
verify_dynamic_service homeassistant host.docker.internal:8123
verify_dynamic_service esphome host.docker.internal:6052
verify_dynamic_service musicassistant host.docker.internal:8095
count_fixed 1 'certResolver: cloudflare' "$dynamic_dir/services.yml"
count_fixed 1 'permanent: true' "$dynamic_dir/services.yml"
count_fixed 3 'middlewares: [admin-auth]' "$dynamic_dir/services.yml"
count_fixed 1 'usersFile: /run/secrets/traefik-users' "$dynamic_dir/services.yml"
[ "$(grep -F -h -c 'Host(`' "$dynamic_dir"/*.yml | awk '{ total += $1 } END { print total + 0 }')" -eq 17 ] || fail 'expected 17 HTTPS routers'
if grep -E 'traefik\.(enable|http)' "$compose" >/dev/null; then
  fail 'legacy Docker labels remain'
fi

for prefix in immich qbittorrent files chat excalidraw pihole traefik docker logs uptime backup ha ha-esphome ha-music ha-flows; do
  count_fixed 1 "url: https://$prefix.\${DOMAIN}" "$glance"
done
count_fixed 1 "homepage.href=https://pihole.${dollar}{DOMAIN:?set DOMAIN=n33lab.com}/admin" "$compose"
count_fixed 1 "FORGEJO__server__DOMAIN=git.${dollar}{DOMAIN:?set DOMAIN=n33lab.com}" "$compose"
count_fixed 1 "FORGEJO__server__ROOT_URL=https://git.${dollar}{DOMAIN:?set DOMAIN=n33lab.com}/" "$compose"
count_fixed 1 "FORGEJO__server__SSH_DOMAIN=git.${dollar}{DOMAIN:?set DOMAIN=n33lab.com}" "$compose"
count_fixed 1 "FORGEJO_URL=${dollar}{1:-https://git.n33lab.com}" "$migration"

for published_port in '"80:80"' '"443:443"' \
  '"192.168.1.33:53:53/tcp"' '"192.168.1.33:53:53/udp"' \
  '"6881:6881"' '"6881:6881/udp"' '"1883:1883"' '"222:22"'; do
  count_fixed 1 "$published_port" "$compose"
done
if grep -Eq '"(9090:8080|3333:80)"|api\.insecure' "$compose"; then
  fail 'retired direct administration ports or insecure API remain'
fi

"$image_pins" "$compose" >/dev/null
[ "$(grep -c '^[[:space:]]*ports:$' "$compose")" -eq 5 ] || fail 'unexpected direct-port publication block'

if grep -E -n 'lab\.lan|nasito\.local|192\.168\.1\.193|\$\{DOMAIN:-localhost\}|(^|[^A-Za-z0-9-])home\.\$\{DOMAIN' \
  "$compose" "$env_example" "$glance" "$dynamic_dir/homeassistant.yml" "$dynamic_dir/esphome.yml" \
  "$dynamic_dir/musicassistant.yml" "$migration" "$deploy" "$recovery" >/dev/null; then
  fail 'active tracked source contains a legacy hostname, address, or domain fallback'
fi

printf '%s\n' 'hostname_matrix_status=PASS' 'image_pin_check=PASS'
