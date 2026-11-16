#!/usr/bin/env bash
# Rotates Slack status with whimsical "thinking" states every 60s.
# Usage: ./thinking-status.sh          (runs forever, rotates every 60s)
#        ./thinking-status.sh once     (sets one random status and exits)
#
# Requires: SLACK_USER_TOKEN env var (xoxp- token with users.profile:write scope)
set -euo pipefail

if [[ -z "${SLACK_USER_TOKEN:-}" ]]; then
  # Try sourcing .env from common locations
  for f in .env "$HOME/.env" "$(git rev-parse --show-toplevel 2>/dev/null)/.env"; do
    if [[ -f "$f" ]]; then
      export "$(grep '^SLACK_USER_TOKEN=' "$f" | head -1)"
      break
    fi
  done
fi

if [[ -z "${SLACK_USER_TOKEN:-}" ]]; then
  echo "ERROR: SLACK_USER_TOKEN not set. Need an xoxp- token with users.profile:write scope." >&2
  exit 1
fi

STATUSES=(
  ':thinking_face:|Pondering...'
  ':brain:|Contemplating...'
  ':moyai:|Pontificating...'
  ':cow:|Ruminating...'
  ':scales:|Deliberating...'
  ':thought_balloon:|Mulling it over...'
  ':books:|Consulting the archives...'
  ':mag:|Cross-referencing...'
  ':dna:|Synthesizing...'
  ':microscope:|Formulating a hypothesis...'
  ':nerd_face:|Peer-reviewing myself...'
  ':hole:|Staring into the void...'
  ':duck:|Asking the rubber duck...'
  ':zap:|Shuffling neurons...'
  ':link:|Connecting dots...'
  ':spaghetti:|Untangling spaghetti...'
  ':couch_and_lamp:|Rearranging mental furniture...'
  ':cave:|Descending into the codebase...'
  ':scroll:|Channeling ancient wisdom...'
  ':crystal_ball:|Summoning the context window...'
  ':sparkles:|Entering the flow state...'
  ':eyes:|Reading the error message this time...'
  ':electric_plug:|Checking if its plugged in...'
  ':bug:|Wondering if this is a feature...'
  ':shushing_face:|Pretending I knew that...'
  ':no_good:|Resisting the urge to refactor...'
)

set_random_status() {
  local entry="${STATUSES[$((RANDOM % ${#STATUSES[@]}))]}"
  local emoji="${entry%%|*}"
  local text="${entry#*|}"

  local response
  response=$(curl -s -X POST "https://slack.com/api/users.profile.set" \
    -H "Authorization: Bearer $SLACK_USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"profile\":{\"status_text\":\"$text\",\"status_emoji\":\"$emoji\",\"status_expiration\":0}}")

  if [[ "$(echo "$response" | grep -o '"ok":true')" ]]; then
    echo "$emoji $text"
  else
    local error
    error=$(echo "$response" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
    echo "ERROR: $error" >&2
    return 1
  fi
}

cleanup() {
  echo ""
  echo "Clearing status..."
  curl -s -X POST "https://slack.com/api/users.profile.set" \
    -H "Authorization: Bearer $SLACK_USER_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"profile":{"status_text":"","status_emoji":"","status_expiration":0}}' > /dev/null
  echo "Status cleared."
  exit 0
}

if [[ "${1:-}" == "once" ]]; then
  set_random_status
else
  trap cleanup SIGINT SIGTERM
  echo "Rotating thinking status every 60s. Ctrl+C to stop and clear."
  while true; do
    set_random_status
    sleep 60
  done
fi
