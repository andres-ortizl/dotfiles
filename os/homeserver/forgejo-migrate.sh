#!/bin/sh
# Migrate private GitHub repos into Forgejo (code + issues + PRs + releases +
# wiki + labels + milestones). Scope: 15 personal repos -> user, 5 33TMT repos
# -> org 33TMT. Idempotent: already-migrated repos are skipped.
#
# Usage: FORGEJO_TOKEN=xxx GITHUB_TOKEN=$(gh auth token) ./forgejo-migrate.sh [forgejo-url] [forgejo-user]
#   FORGEJO_TOKEN: Forgejo web UI -> Settings -> Applications -> Generate Token
set -eu

FORGEJO_URL=${1:-http://git.lab.lan}
FORGEJO_USER=${2:-andrew}
: "${FORGEJO_TOKEN:?Forgejo token (Settings -> Applications)}"
: "${GITHUB_TOKEN:?GitHub token (gh auth token)}"

PERSONAL="exerciseme local-server tmt dsa pyvenv-adapter mypydot obsidian RPELab noname rustlings-ex awesome-wm-theme eng-posts my-vercel-test-andrew relive_challenge static-website"
TMT="hippo lovable-hippo-landing peak-well-backend peak-well-frontend pystart-boilerplate"

RESP=$(mktemp)
trap 'rm -f "$RESP"' EXIT

api() {
  curl -sS -o "$RESP" -w '%{http_code}' \
    -H "Authorization: token $FORGEJO_TOKEN" -H 'Content-Type: application/json' "$@"
}

code=$(api -X POST "$FORGEJO_URL/api/v1/orgs" -d '{"username":"33TMT","visibility":"private"}')
case $code in
  201) echo "org 33TMT: created";;
  409|422) echo "org 33TMT: already exists";;
  *) echo "org 33TMT: FAILED (HTTP $code): $(cat "$RESP")" >&2; exit 1;;
esac

migrate() { # $1 github-owner, $2 repo, $3 forgejo-owner
  code=$(api -X POST "$FORGEJO_URL/api/v1/repos/migrate" -d "{
    \"clone_addr\": \"https://github.com/$1/$2.git\",
    \"auth_token\": \"$GITHUB_TOKEN\",
    \"service\": \"github\",
    \"repo_name\": \"$2\",
    \"repo_owner\": \"$3\",
    \"mirror\": false,
    \"private\": true,
    \"wiki\": true,
    \"issues\": true,
    \"pulls\": true,
    \"releases\": true,
    \"labels\": true,
    \"milestones\": true
  }")
  case $code in
    201) echo "OK   $3/$2";;
    409) echo "SKIP $3/$2 (already exists)";;
    *)   echo "FAIL $3/$2 (HTTP $code): $(cat "$RESP")";;
  esac
}

for r in $PERSONAL; do migrate andres-ortizl "$r" "$FORGEJO_USER"; done
for r in $TMT; do migrate 33TMT "$r" 33TMT; done

echo
echo "Verify counts at $FORGEJO_URL (user $FORGEJO_USER: 15 repos, org 33TMT: 5 repos)."
