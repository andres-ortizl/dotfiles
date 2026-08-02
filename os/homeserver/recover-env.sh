#!/bin/sh
set -eu
umask 077

item_name=n33lab-homeserver-runtime
check_only=false
stage_dir=
install_dir=
restore_dir=
transaction_dir=
transaction_active=false
secrets_created=false

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

cleanup_dir() {
  [ -n "$1" ] && [ -d "$1" ] || return 0
  rm -f "$1"/*
  rmdir "$1"
}

cleanup_artifacts() {
  result=0
  cleanup_dir "$install_dir" || result=1
  cleanup_dir "$restore_dir" || result=1
  cleanup_dir "$stage_dir" || result=1
  cleanup_dir "$transaction_dir" || result=1
  if [ "$secrets_created" = true ] && [ -d "$script_dir/secrets" ]; then
    rmdir "$script_dir/secrets" 2>/dev/null || true
  fi
  return "$result"
}

rollback() {
  result=0
  for attachment in $attachments; do
    target=$(destination "$attachment")
    backup="$transaction_dir/backup-$attachment"
    if [ -f "$backup" ] && [ ! -L "$backup" ]; then
      if { [ -e "$target" ] || [ -L "$target" ]; } && { [ ! -f "$target" ] || [ -L "$target" ]; }; then
        result=1
        continue
      fi
      restore_dir=$(mktemp -d "$(dirname "$target")/.recovery-rollback.XXXXXX") || {
        result=1
        continue
      }
      cp -p "$backup" "$restore_dir/payload" \
        && mv -f "$restore_dir/payload" "$target" \
        && cmp -s "$backup" "$target" \
        || result=1
      cleanup_dir "$restore_dir" || result=1
      restore_dir=
    elif [ -f "$target" ] || [ -L "$target" ]; then
      rm -f "$target" || result=1
    elif [ -e "$target" ]; then
      result=1
    fi
  done
  transaction_active=false
  return "$result"
}

finish() {
  status=$?
  trap - EXIT HUP INT TERM
  if [ "$transaction_active" = true ]; then
    rollback || status=1
  fi
  cleanup_artifacts || status=1
  exit "$status"
}

trap finish EXIT
trap 'exit 1' HUP INT TERM

cleanup_stage() {
  if [ -n "$stage_dir" ] && [ -d "$stage_dir" ]; then
    rm -f "$stage_dir"/*
    rmdir "$stage_dir"
    stage_dir=
  fi
}

if [ "${1-}" = "--check" ]; then
  check_only=true
  shift
fi
[ "$#" -eq 0 ] || fail "Usage: $0 [--check]"

command -v bw >/dev/null 2>&1 || fail "Bitwarden CLI is required"
command -v timeout >/dev/null 2>&1 || fail "timeout is required for bounded external commands"

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
deploy_uid=${SUDO_UID:-$(id -u)}
deploy_gid=${SUDO_GID:-$(id -g)}
stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/n33lab-recovery.XXXXXX")
chmod 700 "$stage_dir"

attachments="homeserver.env immich-server.env immich-ml.env gatus.env cloudflare_dns_api_token traefik-users esphome.env mqtt-passwd mqtt-acl qa-manifest.env qa-nas-credentials.env qa-external.env qa-worker.env"
bcrypt_pattern='^[$]2[aby][$][0-9]{2}[$][./A-Za-z0-9]{53}$'

destination() {
  case "$1" in
    homeserver.env) printf '%s\n' "$script_dir/.env" ;;
    *) printf '%s\n' "$script_dir/secrets/$1" ;;
  esac
}

run_bounded() {
  command -v timeout >/dev/null 2>&1 || return 127
  timeout 60 "$@"
}

item_id=$(run_bounded bw get item "$item_name" 2>/dev/null \
  | awk -v expected_name="$item_name" '
      item_id == "" && match($0, /"id"[[:space:]]*:[[:space:]]*"[0-9a-fA-F-]+"/) {
        value = substr($0, RSTART, RLENGTH)
        sub(/^"id"[[:space:]]*:[[:space:]]*"/, "", value)
        sub(/"$/, "", value)
        item_id = value
      }
      item_name == "" && match($0, /"name"[[:space:]]*:[[:space:]]*"[^"]+"/) {
        value = substr($0, RSTART, RLENGTH)
        sub(/^"name"[[:space:]]*:[[:space:]]*"/, "", value)
        sub(/"$/, "", value)
        item_name = value
      }
      END {
        if (item_id == "" || item_name != expected_name) exit 1
        print item_id
      }
    ') \
  || fail "Bitwarden item is unavailable or ambiguous: $item_name"
[ "${#item_id}" -eq 36 ] || fail "Bitwarden item has an invalid identifier"
case "$item_id" in
  *[!0-9a-fA-F-]*) fail "Bitwarden item has an invalid identifier" ;;
esac

validate_env_names() {
  awk -F= -v allowed="$2" -v required="$3" -v permit_empty="$4" '
    BEGIN {
      split(allowed, allowed_names, " ")
      for (item in allowed_names) allowed_name[allowed_names[item]] = 1
      split(required, required_names, " ")
      for (item in required_names) required_name[required_names[item]] = 1
    }
    /^[[:space:]]*($|#)/ { next }
    {
      key = $1
      if (key !~ /^[A-Z][A-Z0-9_]*$/ || !allowed_name[key] || seen[key]++ || NF < 2) exit 1
      value = substr($0, index($0, "=") + 1)
      if (required_name[key] && value == "") exit 1
      entries++
    }
    END {
      for (key in required_name) if (!seen[key]) exit 1
      if (!permit_empty && entries == 0) exit 1
    }
  ' "$1"
}

validate_attachment() {
  case "$1" in
    homeserver.env)
      validate_env_names "$2" \
        "DOMAIN ACME_EMAIL ACME_CA_SERVER ACME_STORAGE PUID PGID TZ DATA_ROOT UPLOAD_LOCATION DB_PASSWORD DB_USERNAME DB_DATABASE_NAME PIHOLE_PASSWORD PIHOLE_DNS PIHOLE_API_KEY TS_AUTHKEY" \
        "DOMAIN ACME_EMAIL PUID PGID TZ DATA_ROOT UPLOAD_LOCATION DB_PASSWORD DB_USERNAME DB_DATABASE_NAME PIHOLE_PASSWORD PIHOLE_DNS PIHOLE_API_KEY TS_AUTHKEY" 0 \
        && [ "$(awk -F= '$1 == "DOMAIN" { count++; value = substr($0, index($0, "=") + 1) } END { if (count != 1) exit 1; print value }' "$2")" = n33lab.com ]
      ;;
    immich-server.env)
      validate_env_names "$2" "DB_USERNAME DB_PASSWORD DB_DATABASE_NAME" "DB_USERNAME DB_PASSWORD DB_DATABASE_NAME" 0
      ;;
    immich-ml.env)
      validate_env_names "$2" \
        "TZ IMMICH_ENV IMMICH_LOG_LEVEL NO_COLOR IMMICH_HOST IMMICH_PORT MACHINE_LEARNING_MODEL_TTL MACHINE_LEARNING_MODEL_TTL_POLL_S MACHINE_LEARNING_CACHE_FOLDER MACHINE_LEARNING_REQUEST_THREADS MACHINE_LEARNING_MODEL_INTER_OP_THREADS MACHINE_LEARNING_MODEL_INTRA_OP_THREADS MACHINE_LEARNING_WORKERS MACHINE_LEARNING_DEVICE_IDS" \
      "" 1
      ;;
    gatus.env)
      validate_env_names "$2" \
        "GATUS_USERNAME GATUS_PASSWORD_BCRYPT_BASE64" \
        "GATUS_USERNAME GATUS_PASSWORD_BCRYPT_BASE64" 0 \
        && printf '%s\n' "$(env_value "$2" GATUS_USERNAME)" | grep -Eq '^[A-Za-z0-9._-]+$' \
        && printf '%s' "$(env_value "$2" GATUS_PASSWORD_BCRYPT_BASE64)" | base64 -d 2>/dev/null \
          | grep -Eq "$bcrypt_pattern"
      ;;
    esphome.env)
      validate_env_names "$2" "ESPHOME_USERNAME ESPHOME_PASSWORD ESPHOME_TRUSTED_DOMAINS" "ESPHOME_USERNAME ESPHOME_PASSWORD ESPHOME_TRUSTED_DOMAINS" 0
      ;;
    qa-manifest.env)
      validate_env_names "$2" \
        "MODE BASIC_AUTH_CREDENTIALS_FILE HOME_ASSISTANT_CREDENTIALS_FILE FORGEJO_TOKEN_FILE ESPHOME_DEVICE_FILE MUSIC_ASSISTANT_PLAYER_FILE MQTT_CLIENT_FILES_FILE ADMIN_IPV4_SET_FILE CHECKS_DIR" \
        "MODE BASIC_AUTH_CREDENTIALS_FILE HOME_ASSISTANT_CREDENTIALS_FILE FORGEJO_TOKEN_FILE ESPHOME_DEVICE_FILE MUSIC_ASSISTANT_PLAYER_FILE MQTT_CLIENT_FILES_FILE ADMIN_IPV4_SET_FILE CHECKS_DIR" 0 \
        && case "$(env_value "$2" MODE)" in reference|execute) true ;; *) false ;; esac
      ;;
    qa-nas-credentials.env)
      validate_env_names "$2" \
        "BASIC_AUTH_USERNAME BASIC_AUTH_PASSWORD HOME_ASSISTANT_USERNAME HOME_ASSISTANT_PASSWORD FORGEJO_TOKEN ESPHOME_USERNAME ESPHOME_PASSWORD MUSIC_ASSISTANT_TOKEN MQTT_USERNAME MQTT_PASSWORD" \
        "BASIC_AUTH_USERNAME BASIC_AUTH_PASSWORD HOME_ASSISTANT_USERNAME HOME_ASSISTANT_PASSWORD FORGEJO_TOKEN ESPHOME_USERNAME ESPHOME_PASSWORD MUSIC_ASSISTANT_TOKEN MQTT_USERNAME MQTT_PASSWORD" 0
      ;;
    qa-external.env)
      validate_env_names "$2" \
        "MODE WAN_IPV4_FILE NAS_GLOBAL_IPV6_FILE PUBLIC_DNS_RESOLVERS_FILE EXTERNAL_PROBE_COMMAND_FILE" \
        "MODE WAN_IPV4_FILE NAS_GLOBAL_IPV6_FILE PUBLIC_DNS_RESOLVERS_FILE EXTERNAL_PROBE_COMMAND_FILE" 0 \
        && case "$(env_value "$2" MODE)" in reference|execute) true ;; *) false ;; esac
      ;;
    qa-worker.env)
      validate_env_names "$2" "NAS_ENDPOINT EXTERNAL_ENDPOINT" "NAS_ENDPOINT EXTERNAL_ENDPOINT" 0 || return 1
      for endpoint_key in NAS_ENDPOINT EXTERNAL_ENDPOINT; do
        endpoint_value=$(env_value "$2" "$endpoint_key")
        printf '%s\n' "$endpoint_value" | grep -Eq '^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$' || return 1
      done
      ;;
    cloudflare_dns_api_token)
      awk 'NF != 1 || /[=[:space:]]/ { exit 1 } END { if (NR != 1) exit 1 }' "$2"
      ;;
    traefik-users)
      awk 'BEGIN { valid = 0 } /^[[:space:]]*$/ { next } /^[A-Za-z0-9._-]+:\$[^[:space:]]+$/ { valid++; next } { exit 1 } END { if (!valid) exit 1 }' "$2"
      ;;
    mqtt-passwd)
      awk 'BEGIN { valid = 0 } /^[[:space:]]*($|#)/ { next } /^[A-Za-z0-9._-]+:\$[^[:space:]]+$/ { valid++; next } { exit 1 } END { if (!valid) exit 1 }' "$2"
      ;;
    mqtt-acl)
      awk '
        /^[[:space:]]*($|#)/ { next }
        /^user [A-Za-z0-9._-]+$/ { users++; next }
        /^topic (read|write|readwrite) [^[:space:]#+]+$/ { topics++; next }
        { exit 1 }
        END { if (!users || !topics) exit 1 }
      ' "$2"
      ;;
    *) return 1 ;;
  esac
}

env_value() {
  awk -F= -v wanted="$2" '$1 == wanted { print substr($0, index($0, "=") + 1); exit }' "$1"
}

for attachment in $attachments; do
  output="$stage_dir/$attachment"
  if ! run_bounded bw get attachment "$attachment" --itemid "$item_id" --output "$output" >/dev/null 2>&1; then
    fail "required Bitwarden attachment is unavailable: $attachment"
  fi
  [ -f "$output" ] || fail "Bitwarden did not create the requested attachment: $attachment"
  validate_attachment "$attachment" "$output" || fail "attachment schema validation failed: $attachment"
done

for key in DB_USERNAME DB_PASSWORD DB_DATABASE_NAME; do
  [ "$(env_value "$stage_dir/homeserver.env" "$key")" = "$(env_value "$stage_dir/immich-server.env" "$key")" ] \
    || fail "Immich database attachments are inconsistent"
done

if [ "$check_only" = true ]; then
  for attachment in $attachments; do
    target=$(destination "$attachment")
    [ -f "$target" ] && [ ! -L "$target" ] || fail "recovered file is missing: $attachment"
    [ "$(stat -c '%a' "$target")" = 600 ] || fail "recovered file mode is not 600: $attachment"
    [ "$(stat -c '%u' "$target")" = "$deploy_uid" ] || fail "recovered file owner is incorrect: $attachment"
    validate_attachment "$attachment" "$target" || fail "installed file schema validation failed: $attachment"
    cmp -s "$stage_dir/$attachment" "$target" || fail "installed file differs from Bitwarden: $attachment"
  done
  cleanup_stage || fail "unable to remove recovery staging data"
  printf '%s\n' "Bitwarden recovery rehearsal passed"
  exit 0
fi

secrets_dir="$script_dir/secrets"
if [ -e "$secrets_dir" ] || [ -L "$secrets_dir" ]; then
  [ -d "$secrets_dir" ] && [ ! -L "$secrets_dir" ] || fail "secrets destination must be a regular directory"
fi

for attachment in $attachments; do
  target=$(destination "$attachment")
  if [ -e "$target" ] || [ -L "$target" ]; then
    [ -f "$target" ] && [ ! -L "$target" ] || fail "existing destination is not a regular file: $attachment"
  fi
done

if [ ! -d "$secrets_dir" ]; then
  mkdir -m 700 "$secrets_dir"
  secrets_created=true
fi

transaction_dir=$(mktemp -d "$script_dir/.recovery-transaction.XXXXXX")
chmod 700 "$transaction_dir"

for attachment in $attachments; do
  target=$(destination "$attachment")
  if [ -f "$target" ] && [ ! -L "$target" ]; then
    cp -p "$target" "$transaction_dir/backup-$attachment"
  fi
done

transaction_active=true
for attachment in $attachments; do
  target=$(destination "$attachment")
  target_dir=$(dirname "$target")
  install_dir=$(mktemp -d "$target_dir/.recovery-XXXXXX")
  install -m 600 "$stage_dir/$attachment" "$install_dir/payload"
  chown "$deploy_uid:$deploy_gid" "$install_dir/payload"
  mv -f "$install_dir/payload" "$target"
  rmdir "$install_dir"
  install_dir=
done

for attachment in $attachments; do
  target=$(destination "$attachment")
  [ -f "$target" ] && [ ! -L "$target" ] || fail "final destination is not a regular file: $attachment"
  [ "$(stat -c '%a' "$target")" = 600 ] || fail "final destination mode is not 600: $attachment"
  [ "$(stat -c '%u' "$target")" = "$deploy_uid" ] || fail "final destination owner is incorrect: $attachment"
  validate_attachment "$attachment" "$target" || fail "final destination schema is invalid: $attachment"
  cmp -s "$stage_dir/$attachment" "$target" || fail "final destination differs from Bitwarden: $attachment"
done

cleanup_stage || fail "unable to remove recovery staging data"
transaction_active=false
cleanup_dir "$transaction_dir" || fail "unable to remove recovery transaction data"
transaction_dir=
printf '%s\n' "restored 13 validated runtime attachments"
