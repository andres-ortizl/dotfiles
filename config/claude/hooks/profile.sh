#!/bin/sh
# SessionStart / SubagentStart hook: adds a personal per-repo profile from dotfiles to the context.
# SessionStart context never reaches subagents, so each role gets its file through SubagentStart.
# Fails open: any problem prints {} so a session never breaks on its profile.

profiles=/Users/andrew/code/dotfiles/config/claude/profiles

input=$(cat)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
agent=$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)

skip() { printf '{}\n'; exit 0; }

[ -n "$event" ] && [ -n "$cwd" ] || skip

remotes=$(git -C "$cwd" remote -v 2>/dev/null)
case "$remotes" in
  *anyformat-ai/anyformat-monorepo*) profile=anyformat ;;
  *) skip ;;
esac

# The shell inherits the main checkout's .env (ports, flags); in a worktree that overrides the
# worktree's own .env in docker compose, so unset every main .env key for this session's Bash.
if [ "$event" = SessionStart ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  main_env="$(dirname "$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)")/.env"
  case "$cwd" in
    */.claude/worktrees/*)
      [ -r "$main_env" ] && sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/unset \1/p' "$main_env" >> "$CLAUDE_ENV_FILE"
      ;;
  esac
fi

case "$event" in
  SessionStart) role=main ;;
  SubagentStart)
    case "$agent" in
      explorer) role=explorer ;;
      coder | claude-pm:project-developer) role=coder ;;
      reviewer | claude-pm:code-review-reporter) role=reviewer ;;
      *) skip ;;
    esac
    ;;
  *) skip ;;
esac

file="$profiles/$profile/$role.md"
[ -r "$file" ] || skip

jq -n --arg event "$event" --arg body "$(cat "$file")" \
  '{hookSpecificOutput: {hookEventName: $event, additionalContext: $body}}' 2>/dev/null || skip
