#!/bin/sh
set -eu
umask 077

scripts_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
homeserver_dir=$(dirname "$scripts_dir")
verifier="$scripts_dir/verify-hostname-matrix.sh"
root=$(mktemp -d /tmp/n33lab-hostname-matrix.XXXXXX)
trap 'rm -rf "$root"' EXIT
trap 'exit 1' HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_ok() {
  "$@" >/dev/null 2>&1 || fail "expected success: $*"
}

expect_fail() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $*"
  fi
}

make_fixture() {
  destination=$1
  mkdir -p "$destination/config/glance" "$destination/config/traefik/dynamic" "$destination/scripts"
  cp "$homeserver_dir/docker-compose.yml" "$homeserver_dir/.env.example" "$homeserver_dir/deploy.sh" \
    "$homeserver_dir/recover-env.sh" "$homeserver_dir/forgejo-migrate.sh" "$destination/"
  cp "$homeserver_dir/config/glance/glance.yml" "$destination/config/glance/"
  cp "$homeserver_dir/config/traefik/dynamic/"*.yml "$destination/config/traefik/dynamic/"
  cp "$scripts_dir/hostname-matrix.tsv" "$destination/scripts/"
  cp "$scripts_dir/test-image-pins.sh" "$destination/scripts/"
}

expect_ok "$verifier" --help
expect_fail "$verifier" --unknown
expect_ok "$verifier" --homeserver-dir "$homeserver_dir"

make_fixture "$root/duplicate"
printf '%s\n' "    glance-duplicate:" "      rule: 'Host(\`{{ env \"DOMAIN\" }}\`)'" >>"$root/duplicate/config/traefik/dynamic/services.yml"
expect_fail "$verifier" --homeserver-dir "$root/duplicate" --matrix "$root/duplicate/scripts/hostname-matrix.tsv"

make_fixture "$root/missing"
sed -i '/    forgejo:/d' "$root/missing/config/traefik/dynamic/services.yml"
expect_fail "$verifier" --homeserver-dir "$root/missing" --matrix "$root/missing/scripts/hostname-matrix.tsv"

make_fixture "$root/legacy"
printf '%s\n' '# lab.lan' >>"$root/legacy/config/glance/glance.yml"
expect_fail "$verifier" --homeserver-dir "$root/legacy" --matrix "$root/legacy/scripts/hostname-matrix.tsv"

make_fixture "$root/malformed"
sed -i "s/Host(\`chat\./HostRegexp(\`chat\./" "$root/malformed/config/traefik/dynamic/services.yml"
expect_fail "$verifier" --homeserver-dir "$root/malformed" --matrix "$root/malformed/scripts/hostname-matrix.tsv"

make_fixture "$root/direct-port"
sed -i 's/"222:22"/"223:22"/' "$root/direct-port/docker-compose.yml"
expect_fail "$verifier" --homeserver-dir "$root/direct-port" --matrix "$root/direct-port/scripts/hostname-matrix.tsv"

make_fixture "$root/matrix-duplicate"
cat "$root/matrix-duplicate/scripts/hostname-matrix.tsv" >>"$root/matrix-duplicate/scripts/hostname-matrix.tsv.copy"
printf '%s\n' 'n33lab.com\thttp\tglance\tglance:8080\t80,443=traefik' >>"$root/matrix-duplicate/scripts/hostname-matrix.tsv.copy"
expect_fail "$verifier" --homeserver-dir "$root/matrix-duplicate" --matrix "$root/matrix-duplicate/scripts/hostname-matrix.tsv.copy"

make_fixture "$root/matrix-missing"
sed '/^mqtt\.n33lab\.com/d' "$root/matrix-missing/scripts/hostname-matrix.tsv" >"$root/matrix-missing/scripts/hostname-matrix-missing.tsv"
expect_fail "$verifier" --homeserver-dir "$root/matrix-missing" --matrix "$root/matrix-missing/scripts/hostname-matrix-missing.tsv"

printf '%s\n' 'hostname_matrix_tests=PASS'
