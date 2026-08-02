#!/bin/sh
set -eu
umask 077

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

usage() {
  printf 'Usage: %s --output FILE [--project-dir DIR] [--compose FILE] [--env-file FILE]\n' "$0"
}

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(dirname "$script_dir")
compose_file=
env_file=
output=

while [ "$#" -gt 0 ]; do
  case $1 in
    --output)
      [ "$#" -ge 2 ] || fail 'missing value for --output'
      output=$2
      shift 2
      ;;
    --project-dir)
      [ "$#" -ge 2 ] || fail 'missing value for --project-dir'
      project_dir=$2
      shift 2
      ;;
    --compose)
      [ "$#" -ge 2 ] || fail 'missing value for --compose'
      compose_file=$2
      shift 2
      ;;
    --env-file)
      [ "$#" -ge 2 ] || fail 'missing value for --env-file'
      env_file=$2
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *) fail "unknown option: $1" ;;
  esac
done

[ -n "$output" ] || fail '--output is required'
[ -n "$compose_file" ] || compose_file="$project_dir/docker-compose.yml"
[ -n "$env_file" ] || env_file="$project_dir/.env"

command -v timeout >/dev/null 2>&1 || fail 'GNU timeout is required'
timeout --version 2>/dev/null | grep -q 'GNU coreutils' || fail 'GNU timeout is required'
command -v docker >/dev/null 2>&1 || fail 'docker is required'
[ -d "$project_dir" ] && [ ! -L "$project_dir" ] || fail 'project directory is invalid'
[ -f "$compose_file" ] && [ ! -L "$compose_file" ] || fail 'Compose file is invalid'
[ -f "$env_file" ] && [ ! -L "$env_file" ] || fail 'environment file is invalid'

output_dir=$(dirname "$output")
[ -d "$output_dir" ] && [ ! -L "$output_dir" ] || fail 'output directory is invalid'
if [ -e "$output" ] || [ -L "$output" ]; then
  [ -f "$output" ] && [ ! -L "$output" ] || fail 'output path is invalid'
fi

temporary=
work_dir=
cleanup() {
  [ -z "$temporary" ] || rm -f "$temporary"
  [ -z "$work_dir" ] || rm -rf "$work_dir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

run_bounded() {
  timeout 30 "$@" 2>/dev/null
}

compose() {
  run_bounded docker compose --project-directory "$project_dir" --env-file "$env_file" -f "$compose_file" "$@"
}

run_bounded docker compose version >/dev/null || fail 'Docker Compose is unavailable'
compose config --quiet >/dev/null || fail 'Compose configuration is invalid'

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/n33lab-image-lock.XXXXXX")
services_file="$work_dir/services"
compose config --services >"$services_file" || fail 'unable to enumerate services'
[ -s "$services_file" ] || fail 'Compose has no configured services'
awk 'NF != 1 || $1 !~ /^[A-Za-z0-9][A-Za-z0-9_.-]*$/ || seen[$1]++ { exit 1 }' "$services_file" \
  || fail 'configured service list is invalid'

temporary=$(mktemp "$output_dir/.image-lock.XXXXXX")
chmod 600 "$temporary"
printf 'service\tconfigured_image\timage_id\trepo_digests\n' >"$temporary"

while IFS= read -r service; do
  configured_image=$(compose config --images "$service") || fail 'unable to read a configured image'
  [ "$(printf '%s\n' "$configured_image" | wc -l)" -eq 1 ] \
    || fail 'configured image reference is ambiguous'
  printf '%s\n' "$configured_image" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._/:@+-]*$' \
    || fail 'configured image reference is invalid'

  container_ids=$(compose ps -q "$service") || fail 'unable to enumerate running containers'
  [ "$(printf '%s\n' "$container_ids" | awk 'NF { count++ } END { print count + 0 }')" -eq 1 ] \
    || fail 'service must have exactly one running container'
  container_id=$(printf '%s\n' "$container_ids" | awk 'NF { print; exit }')
  printf '%s\n' "$container_id" | grep -Eq '^[A-Za-z0-9_.-]+$' || fail 'container identifier is invalid'

  container_image_id=$(run_bounded docker inspect --type container --format '{{.Image}}' "$container_id") \
    || fail 'unable to inspect the running image identity'
  local_image_id=$(run_bounded docker image inspect --format '{{.Id}}' "$configured_image") \
    || fail 'configured image is unavailable locally'
  printf '%s\n' "$local_image_id" | grep -Eq '^sha256:[0-9a-f]{64}$' || fail 'local image ID is invalid'
  [ "$container_image_id" = "$local_image_id" ] || fail 'running container does not use the configured local image'

  repository=${configured_image%%@*}
  case ${repository##*/} in
    *:*) repository=${repository%:*} ;;
  esac
  case $repository in
    docker.io/*) repository=${repository#docker.io/} ;;
    index.docker.io/*) repository=${repository#index.docker.io/} ;;
  esac

  matches="$work_dir/matches"
  repo_digests="$work_dir/repo-digests"
  : >"$matches"
  run_bounded docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$configured_image" \
    >"$repo_digests" || fail 'unable to inspect RepoDigests'
  while IFS= read -r repo_digest; do
    printf '%s\n' "$repo_digest" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._/:+-]*@sha256:[0-9a-f]{64}$' || continue
    digest_repository=${repo_digest%@sha256:*}
    case $digest_repository in
      docker.io/*) digest_repository=${digest_repository#docker.io/} ;;
      index.docker.io/*) digest_repository=${digest_repository#index.docker.io/} ;;
    esac
    [ "$digest_repository" = "$repository" ] && printf '%s\n' "$repo_digest" >>"$matches"
  done <"$repo_digests"

  sort -u "$matches" -o "$matches"
  [ "$(wc -l <"$matches")" -eq 1 ] || fail 'matching RepoDigest is missing or ambiguous'
  repo_digest=$(cat "$matches")
  printf '%s\t%s\t%s\t%s\n' "$service" "$configured_image" "$local_image_id" "$repo_digest" >>"$temporary"
done <"$services_file"

mv -f "$temporary" "$output"
temporary=
trap - EXIT HUP INT TERM
cleanup
