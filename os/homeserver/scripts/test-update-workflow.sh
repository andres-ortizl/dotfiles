#!/bin/sh
set -eu
umask 077

scripts_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
homeserver_dir=$(dirname "$scripts_dir")
capture="$scripts_dir/capture-image-lock.sh"
prompt="$homeserver_dir/UPDATE_IMAGES.md"
root=$(mktemp -d /tmp/n33lab-update-workflow.XXXXXX)
trap 'rm -rf "$root"' EXIT
trap 'exit 1' HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_fail() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $*"
  fi
}

if grep -Eq '^[[:space:]]*watchtower:|com\.centurylinklabs\.watchtower\.enable' "$homeserver_dir/docker-compose.yml"; then
  fail 'active Watchtower configuration remains'
fi
[ -x "$capture" ] || fail 'capture-image-lock.sh is not executable'
[ -f "$prompt" ] && [ ! -L "$prompt" ] || fail 'UPDATE_IMAGES.md is missing'
"$scripts_dir/test-image-pins.sh" "$homeserver_dir/docker-compose.yml" >/dev/null \
  || fail 'Compose images are not all pinned to the expected digests'
tailscale_caps=$(awk '
  /^  tailscale:$/ { in_service = 1; next }
  in_service && /^  [A-Za-z0-9-]+:$/ { exit }
  in_service && /^[[:space:]]{4}cap_add:$/ { in_caps = 1; next }
  in_caps && /^[[:space:]]{4}[A-Za-z0-9_-]+:/ { in_caps = 0 }
  in_caps && /^[[:space:]]*-[[:space:]]+[A-Za-z_]+$/ { print $2 }
' "$homeserver_dir/docker-compose.yml" | paste -sd, -)
[ "$tailscale_caps" = NET_ADMIN ] || fail 'Tailscale capabilities drifted from NET_ADMIN-only'
grep -Fq 'compose config --images' "$capture" && fail 'capture still uses ambiguous Compose image enumeration'
grep -Fq -- "--format '{{.Config.Image}}'" "$capture" || fail 'capture does not inspect the running configured image'

mkdir -m 700 "$root/bin" "$root/project"
printf '%s\n' 'services:' '  app:' '    image: ghcr.io/example/app:1' >"$root/project/docker-compose.yml"
printf '%s\n' 'DOMAIN=n33lab.com' >"$root/project/.env"
chmod 600 "$root/project/.env"

cat >"$root/bin/timeout" <<'EOF'
#!/bin/sh
if [ "${1-}" = --version ]; then
  if [ "${NON_GNU_TIMEOUT:-0}" = 1 ]; then
    printf '%s\n' 'BusyBox timeout'
  else
    printf '%s\n' 'timeout (GNU coreutils) 9.0'
  fi
  exit 0
fi
[ "${TIMEOUT_FAIL:-0}" != 1 ] || exit 124
shift
exec "$@"
EOF

cat >"$root/bin/docker" <<'EOF'
#!/bin/sh
printf '%s\n' 'TASK3_SECRET_SENTINEL' >&2
[ "${DOCKER_SLEEP:-0}" != 1 ] || sleep 5
case $* in
  'compose version') [ "${COMPOSE_FAIL:-0}" != 1 ] ;;
  compose*' config --quiet') exit 0 ;;
  compose*' config --services') printf '%s\n' app ;;
  compose*' config --images app')
    printf '%s\n' 'ghcr.io/example/app:1' 'ghcr.io/example/sidecar:2'
    ;;
  compose*' ps -q app')
    [ "${IMAGE_CASE:-happy}" != missing ] && printf '%s\n' container-id
    ;;
  inspect*'{{.Config.Image}}'*' container-id')
    printf '%s\n' 'ghcr.io/example/app:1'
    ;;
  inspect*'{{.Image}}'*' container-id')
    printf '%s\n' 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    ;;
  image*' inspect '*'{{.Id}}'*)
    printf '%s\n' 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    ;;
  image*' inspect '*)
    case ${IMAGE_CASE:-happy} in
      happy) printf '%s\n' 'ghcr.io/example/app@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' ;;
      ambiguous)
        printf '%s\n' \
          'ghcr.io/example/app@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' \
          'ghcr.io/example/app@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'
        ;;
      no-digest) : ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF
chmod 755 "$root/bin/timeout" "$root/bin/docker"

test_path="$root/bin:$PATH"
PATH=$test_path "$capture" --project-dir "$root/project" --output "$root/image-lock.tsv" >"$root/happy-output" 2>&1
[ "$(stat -c %a "$root/image-lock.tsv")" = 600 ] || fail 'image lock mode is not 600'
[ "$(wc -l <"$root/image-lock.tsv")" -eq 2 ] || fail 'image lock row count is wrong'
awk -F '\t' 'NF != 4 { exit 1 }' "$root/image-lock.tsv" || fail 'image lock schema is wrong'
grep -Fxq 'service	configured_image	image_id	repo_digests' "$root/image-lock.tsv" || fail 'image lock header is wrong'
grep -Fq 'ghcr.io/example/app@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' "$root/image-lock.tsv" \
  || fail 'image lock digest is missing'
grep -q 'TASK3_SECRET_SENTINEL' "$root/image-lock.tsv" "$root/happy-output" && fail 'secret sentinel escaped capture'

for image_case in missing ambiguous no-digest; do
  expect_fail env PATH="$test_path" IMAGE_CASE=$image_case "$capture" \
    --project-dir "$root/project" --output "$root/$image_case.tsv"
  [ ! -e "$root/$image_case.tsv" ] || fail "failure left output: $image_case"
done

expect_fail env PATH="$test_path" TIMEOUT_FAIL=1 "$capture" \
  --project-dir "$root/project" --output "$root/timeout.tsv"
[ ! -e "$root/timeout.tsv" ] || fail 'timeout left output'
expect_fail env PATH="$test_path" NON_GNU_TIMEOUT=1 "$capture" \
  --project-dir "$root/project" --output "$root/non-gnu-timeout.tsv"
[ ! -e "$root/non-gnu-timeout.tsv" ] || fail 'non-GNU timeout left output'
expect_fail env PATH="$test_path" COMPOSE_FAIL=1 "$capture" \
  --project-dir "$root/project" --output "$root/no-compose.tsv"
[ ! -e "$root/no-compose.tsv" ] || fail 'missing Compose left output'

printf '%s\n' 'prior-lock' >"$root/atomic.tsv"
chmod 600 "$root/atomic.tsv"
expect_fail env PATH="$test_path" IMAGE_CASE=no-digest "$capture" \
  --project-dir "$root/project" --output "$root/atomic.tsv"
[ "$(cat "$root/atomic.tsv")" = prior-lock ] || fail 'failed capture replaced prior lock'

DOCKER_SLEEP=1 PATH=$test_path "$capture" --project-dir "$root/project" --output "$root/interrupted.tsv" >/dev/null 2>&1 &
process=$!
sleep 1
kill -TERM "$process" 2>/dev/null || true
wait "$process" 2>/dev/null && fail 'interrupted capture succeeded'
[ ! -e "$root/interrupted.tsv" ] || fail 'interrupt left output'
if [ -n "$(find "$root" -name '.image-lock.*' -print -quit)" ]; then
  fail 'temporary image lock survived cleanup'
fi

for required in 'AGENTS.md' 'repo_digests' 'RepoDigest' 'source of truth' 'official release notes' \
  'one service at a time' 'exact new digest' 'preserve all volumes' 'prior immutable digest' \
  'relevant service tests' 'manual QA' 'before any commit or push' 'rollback' 'atomic commit' \
  'origin master' 'pause for NAS deployment' 'bulk upgrades' 'floating tags' 'Watchtower' \
  'force-push' 'down -v' 'prune' 'secret' 'guess'; do
  grep -Fiq "$required" "$prompt" || fail "update prompt is missing: $required"
done

printf '%s\n' 'update_workflow_tests=PASS'
