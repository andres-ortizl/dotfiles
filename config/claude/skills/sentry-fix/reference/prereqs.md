# Sentry-fix prereqs

Load env vars from `.env` in the project root using the zsh-safe pattern that tolerates `$var` references in later lines:

```bash
set -a
source .env 2>/dev/null
set +a
```

Plain `source .env` breaks in zsh when any later line interpolates an unset var (e.g. `FOO=$BAR_NOT_SET`) — the `2>/dev/null` swallows those warnings and `set -a` exports everything. If you need specific keys and don't want to source at all, grep them: `export SENTRY_AUTH_TOKEN=$(grep -E '^SENTRY_AUTH_TOKEN=' .env | cut -d= -f2-)`.

## Required env vars

- `SENTRY_AUTH_TOKEN`
- `SENTRY_ORG`
- `SENTRY_PROJECTS` (comma-separated, defaults to `backend,core` if unset)
- `TECH_CHANNEL_ID` — Slack channel ID for `#tech`
- `SENTRY_REVIEWERS` — reviewer pool for the raffle. Each entry must carry **three** tokens joined by `:` — short-name, Slack user ID, GitHub handle. Comma-separated. Example:
  ```
  SENTRY_REVIEWERS="andrew:U09TBQ05346:andres-ortizl,hugo:U0990S84U8Y:hugochinchilla,baka:U07R5PX8293:bakary-camara"
  ```
  The short-name is only for logging; the Slack ID is used in the `<@U...>` channel tag; the GH handle is used for `gh pr edit --add-reviewer`. All three are mandatory. If the env var contains bare names with no IDs, the skill resolves them on first run via `slack_search_users` and the GitHub contributor list, then prints the corrected `SENTRY_REVIEWERS` string for the user to save back to `.env`.

If any are missing, stop and tell the user which to set. Do NOT dispatch anything partially configured.

Also verify the current session is inside a terminal multiplexer (Zellij or tmux). If not, refuse — the autonomous loop will die when the terminal closes.

## Load the Slack MCP send tool

The skill uses `mcp__claude_ai_Slack__slack_send_message` for all `#tech` posts and personal DMs. This tool is deferred in most Claude Code setups. **Before Stage A**, load it explicitly:

```
ToolSearch(query="select:mcp__claude_ai_Slack__slack_send_message", max_results=1)
```

Without this, the first Slack post later in the skill will fail with `InputValidationError` and you'll have to load it mid-flow.
