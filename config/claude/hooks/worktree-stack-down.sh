#!/bin/sh
# SessionEnd hook: frees the compose stack of an anyformat linked worktree when its last Claude session exits.
# A later session in that worktree needs ./scripts/agent-prepare.sh again: teardown drops the volumes.

sessions=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions

input=$(cat)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
session=$(printf '%s' "$input" | jq -r '.session_id // empty')

[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0

case "$(git -C "$cwd" remote -v 2>/dev/null)" in
  *anyformat-ai/anyformat-monorepo*) ;;
  *) exit 0 ;;
esac

root=$(git -C "$cwd" rev-parse --show-toplevel) || exit 0
git_dir=$(git -C "$cwd" rev-parse --absolute-git-dir) || exit 0
common_dir=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir) || exit 0
[ "$git_dir" != "$common_dir" ] || exit 0
[ -x "$root/.venv/bin/af" ] || exit 0

for entry in "$sessions"/*.json; do
  [ -f "$entry" ] || continue
  other=$(jq -r '[.pid, .sessionId, .cwd] | @tsv' "$entry" 2>/dev/null) || continue
  pid=$(printf '%s' "$other" | cut -f1)
  id=$(printf '%s' "$other" | cut -f2)
  other_cwd=$(printf '%s' "$other" | cut -f3)
  [ "$id" != "$session" ] || continue
  case "$other_cwd/" in
    "$root"/*) kill -0 "$pid" 2>/dev/null && exit 0 ;;
  esac
done

# SessionEnd hooks are cancelled after 1.5s and a teardown takes longer, so it must outlive the hook.
cd "$root" || exit 0
nohup .venv/bin/af worktree teardown --stack-only </dev/null >>"$git_dir/session-end-teardown.log" 2>&1 &
exit 0
