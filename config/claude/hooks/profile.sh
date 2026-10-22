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
