#!/bin/sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/homeserver-manage-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
trap 'exit 1' HUP INT TERM

mkdir -p "$test_dir/project/scripts" "$test_dir/bin"
cp "$script_dir/../scripts/manage.sh" "$test_dir/project/scripts/manage.sh"
git init -q "$test_dir/project"
: >"$test_dir/project/.env"
printf 'services: {}\n' >"$test_dir/project/docker-compose.yml"
printf '#!/bin/sh\nexit 0\n' >"$test_dir/project/deploy.sh"
chmod +x "$test_dir/project/deploy.sh"

# Docker is simulated because these checks must not connect to the NAS daemon.
cat >"$test_dir/bin/docker" <<'DOCKER'
#!/bin/sh
set -eu
case "$*" in
  *' config --quiet') exit 0 ;;
  *' config --services') printf 'app\n' ;;
  *' config --images') printf '%s\n' "$TEST_IMAGE" ;;
  *' ps -q app') printf 'container123\n' ;;
  'inspect --type container --format {{.Config.Image}} '*) printf '%s\n' "$TEST_IMAGE" ;;
  'inspect --type container --format {{.Image}} '*) printf '%s\n' "$TEST_RUNNING_ID" ;;
  'image inspect --format {{.Id}} '*)
    case "$*" in
      *:stable) printf '%s\n' "$TEST_NEWER_ID" ;;
      *) printf '%s\n' "$TEST_RUNNING_ID" ;;
    esac
    ;;
  'image inspect --format {{range .RepoDigests}}{{println .}}{{end}} '*)
    case "$*" in
      *" $TEST_RUNNING_ID") printf '%s\n' "$TEST_REPO_DIGESTS" ;;
      *) printf 'RepoDigests must be read from the running image ID\n' >&2; exit 1 ;;
    esac
    ;;
  *) printf 'Unexpected Docker invocation: %s\n' "$*" >&2; exit 1 ;;
esac
DOCKER
chmod +x "$test_dir/bin/docker"
PATH="$test_dir/bin:$PATH"
export PATH

digest=$(printf '%064d' 0 | tr 0 a)
TEST_RUNNING_ID=sha256:$(printf '%064d' 0 | tr 0 b)
TEST_NEWER_ID=sha256:$(printf '%064d' 0 | tr 0 c)
TEST_REPO_DIGESTS="example/app@sha256:$digest"
export TEST_RUNNING_ID TEST_NEWER_ID TEST_REPO_DIGESTS
manage=$test_dir/project/scripts/manage.sh
failures=0

expect() {
  expected=$1
  name=$2
  shift 2
  if output=$("$@" 2>&1); then result=success; else result=failure; fi
  if [ "$result" = "$expected" ]; then
    printf 'PASS: %s\n' "$name"
  else
    printf 'FAIL: %s\n%s\n' "$name" "$output" >&2
    failures=$((failures + 1))
  fi
}

expect success 'accept a moving tag' env TEST_IMAGE=example/app:stable sh "$manage" check
expect success 'accept a digest pin' env TEST_IMAGE="example/app:1.2@sha256:$digest" sh "$manage" check
expect success 'accept a tagged private registry image' env TEST_IMAGE=registry.example:5000/team/app:stable sh "$manage" check
expect failure 'reject an implicit latest tag' env TEST_IMAGE=example/app sh "$manage" check
expect failure 'reject a registry port without an image tag' env TEST_IMAGE=registry.example:5000/team/app sh "$manage" check
expect failure 'reject a malformed digest' env TEST_IMAGE=example/app:stable@sha256:abc sh "$manage" check

lock=$test_dir/running-images.tsv
expect success 'lock the running image even after its tag has moved' env TEST_IMAGE=example/app:stable sh "$manage" lock-images --output "$lock"
if [ -f "$lock" ] && [ "$(stat -c '%a' "$lock")" = 600 ] &&
  awk -F '\t' -v image_id="$TEST_RUNNING_ID" -v digest="$TEST_REPO_DIGESTS" '
    NR == 2 { valid = ($1 == "app" && $2 == "example/app:stable" && $3 == image_id && $4 == digest) }
    END { exit !(NR == 2 && valid) }
  ' "$lock"; then
  printf 'PASS: lock contains the immutable running image with private permissions\n'
else
  printf 'FAIL: lock does not contain the expected running image or permissions\n' >&2
  failures=$((failures + 1))
fi

expect success 'lock a digest-pinned image' env TEST_IMAGE="example/app:1.2@sha256:$digest" sh "$manage" lock-images --output "$lock"
expect failure 'reject a pinned digest that does not match the running image' env TEST_IMAGE="example/app@${TEST_NEWER_ID}" sh "$manage" lock-images --output "$lock"
expect failure 'reject an ambiguous running RepoDigest' env TEST_IMAGE=example/app:stable TEST_REPO_DIGESTS="$TEST_REPO_DIGESTS
example/app@$TEST_NEWER_ID" sh "$manage" lock-images --output "$lock"

[ "$failures" -eq 0 ]
