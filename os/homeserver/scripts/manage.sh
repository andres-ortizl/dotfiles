#!/bin/sh
set -eu
umask 077

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(dirname "$script_dir")
compose_file=$project_dir/docker-compose.yml
env_file=$project_dir/.env
temporary_dir=

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
cleanup() { [ -z "$temporary_dir" ] || rm -rf "$temporary_dir"; }
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

require_tools() {
  for tool in awk grep mktemp rm sort git docker; do
    command -v "$tool" >/dev/null 2>&1 || fail "required command unavailable: $tool"
  done
  command -v timeout >/dev/null 2>&1 || fail 'GNU timeout is required'
  timeout --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU timeout is required'
  [ -f "$compose_file" ] && [ ! -L "$compose_file" ] || fail 'Compose file is invalid'
  [ -f "$env_file" ] && [ ! -L "$env_file" ] || fail 'environment file is invalid'
}

run_bounded() { timeout 60 "$@" 2>/dev/null; }
compose() { run_bounded docker compose --project-directory "$project_dir" --env-file "$env_file" -f "$compose_file" "$@"; }

services_file=
list_services() {
  services_file=${temporary_dir:-${TMPDIR:-/tmp}}/services
  compose config --services >"$services_file" || fail 'unable to enumerate Compose services'
  [ -s "$services_file" ] || fail 'Compose has no configured services'
  awk 'NF != 1 || $1 !~ /^[A-Za-z0-9][A-Za-z0-9_.-]*$/ || seen[$1]++ { exit 1 }' "$services_file" \
    || fail 'configured service list is invalid'
}

valid_service() {
  awk -v wanted="$1" '$1 == wanted { found=1 } END { exit !found }' "$services_file"
}

check_pins() {
  images_file=$temporary_dir/images
  compose config --images >"$images_file" || fail 'unable to enumerate Compose images'
  [ "$(wc -l <"$services_file")" -eq "$(wc -l <"$images_file")" ] || fail 'every service must define one image'
  awk '
    NF != 1 { exit 1 }
    {
      count=split($1, parts, "@sha256:")
      if (count != 2 || parts[1] !~ /^[A-Za-z0-9][A-Za-z0-9._:/-]*$/ || parts[2] !~ /^[0-9a-f]+$/ || length(parts[2]) != 64) exit 1
    }
  ' "$images_file" \
    || fail 'every service image must be exactly digest-pinned'
}

check() {
  require_tools
  temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/homeserver-manage.XXXXXX")
  git -C "$project_dir" status --porcelain --untracked-files=no | grep -q . && fail 'tracked repository changes block operation' || :
  "$project_dir/deploy.sh" --check >/dev/null || fail 'deployment preflight failed'
  compose config --quiet || fail 'Compose configuration validation failed'
  list_services
  check_pins
}

validate_output() {
  output=$1
  output_dir=$(dirname "$output")
  [ -d "$output_dir" ] && [ ! -L "$output_dir" ] || fail 'output directory is invalid'
  if [ -e "$output" ] || [ -L "$output" ]; then
    [ -f "$output" ] && [ ! -L "$output" ] || fail 'output path is invalid'
  fi
}

repo_name() {
  repository=${1%%@*}
  case ${repository##*/} in *:*) repository=${repository%:*} ;; esac
  case $repository in docker.io/*) repository=${repository#docker.io/} ;; index.docker.io/*) repository=${repository#index.docker.io/} ;; esac
  printf '%s\n' "$repository"
}

lock_images() {
  [ "$#" -eq 2 ] && [ "$1" = --output ] || fail 'usage: lock-images --output FILE'
  output=$2
  require_tools
  validate_output "$output"
  if [ -z "$temporary_dir" ]; then
    temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/homeserver-lock.XXXXXX")
  fi
  compose config --quiet || fail 'Compose configuration validation failed'
  list_services
  temporary=$temporary_dir/lock
  printf 'service\tconfigured_image\trunning_image_id\trepo_digest\n' >"$temporary"
  while IFS= read -r service; do
    container_ids=$(compose ps -q "$service") || fail 'unable to enumerate running containers'
    [ "$(printf '%s\n' "$container_ids" | awk 'NF { count++ } END { print count + 0 }')" -eq 1 ] || fail 'service must have exactly one running container'
    container_id=$(printf '%s\n' "$container_ids" | awk 'NF { print; exit }')
    printf '%s\n' "$container_id" | grep -Eq '^[A-Za-z0-9_.-]+$' || fail 'container identifier is invalid'
    configured=$(run_bounded docker inspect --type container --format '{{.Config.Image}}' "$container_id") || fail 'unable to inspect configured image'
    printf '%s\n' "$configured" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._/:@+-]*$' || fail 'configured image reference is invalid'
    running_id=$(run_bounded docker inspect --type container --format '{{.Image}}' "$container_id") || fail 'unable to inspect running image identity'
    printf '%s\n' "$running_id" | grep -Eq '^sha256:[0-9a-f]{64}$' || fail 'running image ID is invalid'
    local_id=$(run_bounded docker image inspect --format '{{.Id}}' "$configured") || fail 'configured image is unavailable locally'
    [ "$running_id" = "$local_id" ] || fail 'running container does not use configured local image'
    repository=$(repo_name "$configured")
    run_bounded docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$configured" >"$temporary_dir/digests" || fail 'unable to inspect RepoDigests'
    awk -v repository="$repository" '
      $0 ~ /^[A-Za-z0-9][A-Za-z0-9._/:+-]*@sha256:[0-9a-f]+$/ { digest=$0; sub(/^.*@sha256:/, "", digest); if (length(digest) != 64) next; name=$0; sub(/@sha256:.*/, "", name); sub(/^docker.io\//, "", name); sub(/^index.docker.io\//, "", name); if (name == repository) print $0 }
    ' "$temporary_dir/digests" | sort -u >"$temporary_dir/matches"
    [ "$(wc -l <"$temporary_dir/matches")" -eq 1 ] || fail 'matching RepoDigest is missing or ambiguous'
    repo_digest=$(cat "$temporary_dir/matches")
    printf '%s\t%s\t%s\t%s\n' "$service" "$configured" "$running_id" "$repo_digest" >>"$temporary"
  done <"$services_file"
  chmod 600 "$temporary"
  mv -f "$temporary" "$output"
}

container_ok() {
  state=$(run_bounded docker inspect --type container --format '{{.State.Status}}' "$1") || return 1
  health=$(run_bounded docker inspect --type container --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$1") || return 1
  [ "$state" = running ] && [ "$health" != unhealthy ]
}

verify_services() {
  while IFS= read -r service; do
    container_ids=$(compose ps -q "$service") || fail 'unable to inspect deployed containers'
    [ "$(printf '%s\n' "$container_ids" | awk 'NF { count++ } END { print count + 0 }')" -eq 1 ] || fail "service is not running: $service"
    container_id=$(printf '%s\n' "$container_ids" | awk 'NF { print; exit }')
    container_ok "$container_id" || fail "service is not healthy: $service"
  done
}

deploy() {
  [ "$#" -ge 1 ] && [ "$#" -le 1 ] || fail 'usage: deploy SERVICE|all'
  target=$1
  check
  lock_file=$temporary_dir/pre-deploy.tsv
  lock_images --output "$lock_file"
  if [ "$target" = all ]; then
    "$project_dir/deploy.sh" >/dev/null || fail 'deployment failed'
  else
    valid_service "$target" || fail "unknown service: $target"
    "$project_dir/deploy.sh" "$target" >/dev/null || fail 'deployment failed'
  fi
  if [ "$target" = all ]; then verify_services <"$services_file"; else printf '%s\n' "$target" | verify_services; fi
}

rollback() {
  [ "$#" -eq 2 ] || fail 'usage: rollback SERVICE IMAGE_REF@sha256:DIGEST'
  service=$1
  image_ref=$2
  require_tools
  temporary_dir=$(mktemp -d "${TMPDIR:-/tmp}/homeserver-rollback.XXXXXX")
  compose config --quiet || fail 'Compose configuration validation failed'
  list_services
  valid_service "$service" || fail "unknown service: $service"
  printf '%s\n' "$image_ref" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._:/-]*@sha256:[0-9a-f]{64}$' || fail 'rollback image must be an immutable full reference'
  override=$temporary_dir/override.yml
  printf 'services:\n  %s:\n    image: %s\n' "$service" "$image_ref" >"$override"
  chmod 600 "$override"
  run_bounded docker compose --project-directory "$project_dir" --env-file "$env_file" -f "$compose_file" -f "$override" config --quiet || fail 'rollback Compose configuration is invalid'
  run_bounded docker compose --project-directory "$project_dir" --env-file "$env_file" -f "$compose_file" -f "$override" up -d "$service" >/dev/null || fail 'rollback deployment failed'
  container_ids=$(run_bounded docker compose --project-directory "$project_dir" --env-file "$env_file" -f "$compose_file" -f "$override" ps -q "$service") || fail 'unable to inspect rollback container'
  [ "$(printf '%s\n' "$container_ids" | awk 'NF { count++ } END { print count + 0 }')" -eq 1 ] || fail 'rollback service is not running'
  container_id=$(printf '%s\n' "$container_ids" | awk 'NF { print; exit }')
  container_ok "$container_id" || fail 'rollback service is not healthy'
}

prune_images() {
  [ "$#" -eq 1 ] && [ "$1" = --yes ] || fail 'usage: prune-images --yes'
  check
  verify_services <"$services_file"
  run_bounded docker image prune -a -f >/dev/null || fail 'image prune failed'
}

usage() { printf '%s\n' "Usage: $0 check | lock-images --output FILE | deploy SERVICE|all | rollback SERVICE IMAGE_REF@sha256:DIGEST | prune-images --yes"; }

case ${1-} in
  check) shift; [ "$#" -eq 0 ] || fail 'check takes no arguments'; check; printf '%s\n' 'check passed' ;;
  lock-images) shift; lock_images "$@"; printf '%s\n' 'image lock captured' ;;
  deploy) shift; deploy "$@"; printf '%s\n' 'deployment verified' ;;
  rollback) shift; rollback "$@"; printf '%s\n' 'rollback verified' ;;
  prune-images) shift; prune_images "$@"; printf '%s\n' 'unused images pruned' ;;
  *) usage >&2; exit 2 ;;
esac
