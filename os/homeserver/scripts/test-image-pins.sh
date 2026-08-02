#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd "$(dirname "$0")" && pwd)
compose=${1:-"$script_dir/../docker-compose.yml"}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/n33lab-image-pins.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

expected=$(cat <<'EOF'
backrest|garethgeorge/backrest@sha256:b852979754281026230cc69fb11428e6d57c9a97784ab4a444ffc7934c53a215
database|ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23
dhcphelper|noamokman/dhcp-helper@sha256:25a33e63a20f7ec06465653c40ccde3f692a23074d566ee9dcbb11d75307d538
dozzle|amir20/dozzle@sha256:1c1060cfb5402093c4e0f03f3534d7deaffeb0a6f6dd034e7c5f244603f35fb3
docker-socket-proxy|tecnativa/docker-socket-proxy@sha256:753044cb0851ce53ab44c2504872ff02ae37be9c294fa8abea3754074e61eab4
dockhand|fnsys/dockhand@sha256:29d4183d8aef2cc7fbc50750fa11434ec331e044647288ae47fe15260e68a44c
esphome|ghcr.io/esphome/esphome@sha256:de90d689b89e20f171b0fbdd0dfea31b21ef647aa7e83d6efd2916ca6e7a30d2
excalidraw|excalidraw/excalidraw@sha256:f7ee194addd607bf831d2af0f0a34463dd4225e426cf35199ef0b12a803398e9
filebrowser|gtstef/filebrowser@sha256:fc213590ebc090cb8205125cd3ecdfa9066b9ed4a0b53fe2570972d6a3379e73
forgejo|codeberg.org/forgejo/forgejo@sha256:dbb0f88677f0c65cd1b66fb83504225aa5a04c4bc4a5ffdf9fc9a3a6d5bb1c68
gatus|ghcr.io/twin/gatus@sha256:c5f210d095fa78e6efaa20ffeb14803f2ba4f10615e16a6d12087697149617f0
authelia|authelia/authelia@sha256:b5f415d5f14b154c2aa2b186d9f329d879e223da36e115cd871db4c261d5af54
glance|glanceapp/glance@sha256:32ab73d80f2b8b5fb0735b0431deb36b93fbb6b2fb43592449b0178c8b83e350
homeassistant|ghcr.io/home-assistant/home-assistant@sha256:5a531753cea96444200158fc2b0ac7ccd739291ec50414877b396de6e0bb29b3
immich-machine-learning|ghcr.io/immich-app/immich-machine-learning@sha256:b3deefd1826f113824e9d7bc30d905e7f823535887d03f869330946b6db3b44a
immich-server|ghcr.io/immich-app/immich-server@sha256:46dedfc5848f7313bd6b584ea9f2648057430307aad6de56de968f6710a72cae
mosquitto|eclipse-mosquitto@sha256:6f8d8a947c506f8a2290ec65cd4bd2bc7cb4d43fb5f6271f861cb013e2ef9797
music-assistant|ghcr.io/music-assistant/server@sha256:5500c53c5129bbabfb0de2c2c298fd0ef15fe34207bbe5794f49c587b76bde95
node-red|nodered/node-red@sha256:10f40d0a83e7e5852b13d4d472b2006b05b1cca6d55e2f29a55a12c25a630cb6
openwebui|ghcr.io/open-webui/open-webui@sha256:6a773e5c3a246b65cbe74ce942b294292c0e5f81c138f703d111bc162f7d7c3d
pihole|pihole/pihole@sha256:f7d1be836e3bc608b56d82fc9904f5a831cdfbc0dc9c6d58f94e4c985c70038b
qbittorrent|lscr.io/linuxserver/qbittorrent@sha256:b024436f8ca665d16d9a997d26fd27fdf867ee5566ba09f32764e7b2976d3e02
redis|docker.io/valkey/valkey:8-bookworm@sha256:fea8b3e67b15729d4bb70589eb03367bab9ad1ee89c876f54327fc7c6e618571
tailscale|tailscale/tailscale@sha256:25cde9ad76020b0e29229136d0c38b5962e9a0e1774ffac9b0df68e4a37d6cf0
traefik|traefik@sha256:4df0a50fcf71b454c0d7ad17675776dc8d37359deae3291895bdaa008c1b9972
EOF
)

extract() {
    awk '/^  [A-Za-z0-9-]+:$/ { service=$1; sub(/:$/, "", service) } /^    image: / { print service "|" $2 }' "$1"
}

check() {
    file=$1
    [ "$(extract "$file" | wc -l)" -eq 25 ] || return 1
    extract "$file" | sort >"$tmp/actual"
    printf '%s\n' "$expected" | sort >"$tmp/expected"
    cmp -s "$tmp/actual" "$tmp/expected" || return 1
    [ "$(extract "$file" | cut -d'|' -f2 | grep -Ec '^.+@sha256:[0-9a-f]{64}$')" -eq 25 ] || return 1
}

check "$compose"
sed '0,/sha256:[0-9a-f]*/s//sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' "$compose" >"$tmp/mismatch.yml"
if check "$tmp/mismatch.yml"; then exit 1; fi
sed '0,/@sha256:[0-9a-f]*/s//@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' "$compose" >"$tmp/duplicate.yml"
if check "$tmp/duplicate.yml"; then exit 1; fi
sed '0,/@sha256:[0-9a-f]*/s///' "$compose" >"$tmp/unpinned.yml"
if check "$tmp/unpinned.yml"; then exit 1; fi

printf '%s\n' 'image pin check passed: 25 exact pinned service images'
