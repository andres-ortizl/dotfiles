#!/usr/bin/env bash
# Sets Slack user status to a random "thinking" state.
# Requires SLACK_USER_TOKEN env var (xoxp-... with users.profile:write scope)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATUSES_FILE="$SCRIPT_DIR/statuses.json"

if [[ -z "${SLACK_USER_TOKEN:-}" ]]; then
  echo "ERROR: SLACK_USER_TOKEN not set. Need an xoxp- token with users.profile:write scope." >&2
  exit 1
fi

# Pick a random status
ENTRY=$(jq -c ".[ $(jq length "$STATUSES_FILE" | xargs -I{} bash -c 'echo $(( RANDOM % {} ))') ]" "$STATUSES_FILE")
EMOJI=$(echo "$ENTRY" | jq -r '.emoji')
TEXT=$(echo "$ENTRY" | jq -r '.text')

# Set status via Slack API
RESPONSE=$(curl -s -X POST "https://slack.com/api/users.profile.set" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"profile\":{\"status_text\":\"$TEXT\",\"status_emoji\":\"$EMOJI\",\"status_expiration\":0}}")

OK=$(echo "$RESPONSE" | jq -r '.ok')
if [[ "$OK" == "true" ]]; then
  echo "$EMOJI $TEXT"
else
  ERROR=$(echo "$RESPONSE" | jq -r '.error')
  echo "ERROR: $ERROR" >&2
  exit 1
fi
