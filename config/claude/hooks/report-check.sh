#!/usr/bin/env bash
# SubagentStop for coder, reviewer and explorer: send a report back once when it lacks the lines its agent file names.
set -euo pipefail

input=$(cat)
[ "$(jq -r '.stop_hook_active // false' <<<"$input")" = true ] && exit 0
# A slices-wave agent reports through its schema, which already requires these fields.
[[ "$(jq -r '.agent_transcript_path // ""' <<<"$input")" == */subagents/workflows/* ]] && exit 0

report=$(jq -r '.last_assistant_message // ""' <<<"$input")
ending=$(tail -c 1500 <<<"$report")

missing=()
for line in "Not checked:" "Signals:"; do
  grep -qF "$line" <<<"$ending" || missing+=("$line")
done
if [ "$(jq -r '.agent_type // ""' <<<"$input")" = coder ]; then
  grep -qF "Red run:" <<<"$report" || missing+=("Red run:")
fi
[ ${#missing[@]} -eq 0 ] && exit 0

jq -n --arg m "$(printf '`%s` ' "${missing[@]}")" \
  '{decision: "block", reason: ("Finish your report with the lines your agent file names. Missing: " + $m)}'
