#!/bin/sh
set -eu
umask 077

scripts_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
homeserver_dir=$(dirname "$scripts_dir")
root=$(mktemp -d "${TMPDIR:-/tmp}/n33lab-authelia.XXXXXX")
trap 'rm -rf "$root"' EXIT HUP INT TERM

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

expect_fail() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $*"
  fi
}

compose="$homeserver_dir/docker-compose.yml"
dynamic="$homeserver_dir/config/traefik/dynamic/services.yml"
config="$homeserver_dir/config/authelia/configuration.yml"

cat >"$root/validate.py" <<'PY'
import sys
import yaml

compose, dynamic, config = map(yaml.safe_load, [open(path, encoding="utf-8") for path in sys.argv[1:]])
service = compose["services"]["authelia"]
assert service["image"] == "authelia/authelia@sha256:b5f415d5f14b154c2aa2b186d9f329d879e223da36e115cd871db4c261d5af54"
assert "ports" not in service
assert service["networks"] == ["traefik"]
assert "./config/authelia/configuration.yml:/config/configuration.yml:ro" in service["volumes"]
assert "./data/authelia:/data" in service["volumes"]
assert service["healthcheck"]["test"] == ["CMD", "authelia", "healthcheck"]
assert service["environment"] == [
    "X_AUTHELIA_CONFIG_FILTERS=template",
    "AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE=/run/secrets/authelia-jwt",
    "AUTHELIA_SESSION_SECRET_FILE=/run/secrets/authelia-session",
    "AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE=/run/secrets/authelia-storage-encryption",
]
secret_targets = {
    item if isinstance(item, str) else item["source"]:
    item if isinstance(item, str) else item.get("target", item["source"])
    for item in service["secrets"]
}
assert secret_targets == {
    "authelia_jwt": "authelia-jwt",
    "authelia_session": "authelia-session",
    "authelia_storage_encryption": "authelia-storage-encryption",
    "authelia_users": "authelia-users",
}
assert config["server"]["address"] == "tcp4://:9091"
assert config["log"]["level"] == "info"
assert config["log"]["file_path"] == "/dev/stdout"
assert config["authentication_backend"]["file"]["path"] == "/run/secrets/authelia-users"
assert config["authentication_backend"]["file"]["password"]["algorithm"] == "argon2"
assert config["authentication_backend"]["file"]["password"]["argon2"]["variant"] == "argon2id"
assert config["totp"] == {"issuer": "n33lab.com"}
assert config["access_control"]["default_policy"] == "deny"
policies = {rule["domain"]: rule["policy"] for rule in config["access_control"]["rules"]}
assert policies == {
    "n33lab.com": "one_factor",
    "uptime.n33lab.com": "one_factor",
    "ha-flows.n33lab.com": "one_factor",
    "traefik.n33lab.com": "one_factor",
    "docker.n33lab.com": "one_factor",
    "logs.n33lab.com": "one_factor",
    "backup.n33lab.com": "one_factor",
}
assert config["session"]["cookies"] == [{
    "domain": "n33lab.com",
    "authelia_url": "https://auth.n33lab.com",
    "default_redirection_url": "https://n33lab.com",
}]
assert config["session"]["inactivity"] == "1h"
assert config["session"]["expiration"] == "8h"
assert config["session"]["remember_me"] == "1M"
assert config["storage"]["local"]["path"] == "/data/db.sqlite3"
assert config["notifier"]["filesystem"]["filename"] == "/data/notification.txt"
assert config["regulation"]

middlewares = dynamic["http"]["middlewares"]
assert set(middlewares) == {"authelia", "https-redirect"}
forward = middlewares["authelia"]["forwardAuth"]
assert forward["address"] == "http://authelia:9091/api/authz/forward-auth"
assert forward["trustForwardHeader"] is True
assert forward["authResponseHeaders"] == ["Remote-User", "Remote-Groups", "Remote-Name", "Remote-Email"]
routers = dynamic["http"]["routers"]
protected = {"glance", "dashboard", "dockhand", "gatus", "dozzle", "backrest", "node-red"}
assert routers["http-redirect"]["middlewares"] == ["https-redirect"]
assert {name for name, route in routers.items() if route.get("middlewares") == ["authelia"]} == protected
assert routers["auth"]["service"] == "authelia"
assert "middlewares" not in routers["auth"]
assert dynamic["http"]["services"]["authelia"]["loadBalancer"]["servers"] == [{"url": "http://authelia:9091"}]
PY

validate() {
  python "$root/validate.py" "$1" "$2" "$3"
}

validate "$compose" "$dynamic" "$config" || fail 'Authelia contract is invalid'
grep -Eq '^  authelia:$' "$compose" || fail 'Authelia service is missing'
if grep -Eq 'traefik-users|admin-auth|basicAuth|GATUS_|gatus\.env' "$compose" "$dynamic" "$config"; then
  fail 'legacy authentication remains active'
fi
if grep -Eq '^(security:|[[:space:]]+basic:)' "$homeserver_dir/config/gatus/config.yaml"; then
  fail 'a native-auth application was added'
fi

sed 's#authelia/authelia@sha256:[0-9a-f]*#authelia/authelia:latest#' "$compose" >"$root/unpinned.yml"
expect_fail validate "$root/unpinned.yml" "$dynamic" "$config"

sed '/    - domain: logs.n33lab.com/,+1d' "$config" >"$root/missing-policy.yml"
expect_fail validate "$compose" "$dynamic" "$root/missing-policy.yml"

sed '0,/middlewares: \[https-redirect\]/s//middlewares: [authelia]/' "$dynamic" >"$root/global-middleware.yml"
expect_fail validate "$compose" "$root/global-middleware.yml" "$config"

printf '%s\n' 'authelia_status=PASS'
