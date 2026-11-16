---
name: thinking-status
description: "Set a random whimsical 'thinking' status on Slack. Use with /loop 1m for continuous rotation."
triggers:
  - thinking status
  - slack status
  - vibe status
---

# Thinking Status

Set a random Claude-style "thinking" status on the user's Slack profile.

## Usage

Run once:
```
/thinking-status
```

Run on a loop (every minute):
```
/loop 1m /thinking-status
```

## How it works

1. Run the `set_status.sh` script which picks a random status from `statuses.json` and sets it via the Slack API.

```bash
~/.claude/skills/thinking-status/set_status.sh
```

2. Report which status was set.

## Requirements

- `SLACK_USER_TOKEN` env var must be set (an `xoxp-` token with `users.profile:write` scope)
- `jq` and `curl` must be available

## To clear the status

```bash
curl -s -X POST "https://slack.com/api/users.profile.set" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"profile":{"status_text":"","status_emoji":"","status_expiration":0}}'
```
