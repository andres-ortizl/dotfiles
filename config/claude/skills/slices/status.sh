#!/usr/bin/env bash
# One line per PR: state, base, head, CI, review bot, mergeability, and READY:
# yes, or no with the first condition that fails. A PR stacked on a listed PR is ready only when that PR is.
# Usage: status.sh <loop dir or loop.md>       every PR linked in the loop, then its open signals
#        status.sh <PR url | owner/repo#N>...   those PRs only
set -euo pipefail

usage="usage: status.sh <loop dir or loop.md> | <PR url | owner/repo#N>..."
loop=""
if [ -e "${1:?$usage}" ]; then
  loop="$1"
  [ -d "$loop" ] && loop="$loop/loop.md"
  urls=$(grep -oE 'github\.com/[^/ ]+/[^/ ]+/pull/[0-9]+' "$loop" | sort -u -t/ -k5,5n)
else
  urls=$(for ref in "$@"; do
    if [[ "$ref" =~ ^([^/#[:space:]]+/[^/#[:space:]]+)#([0-9]+)$ ]]; then
      echo "github.com/${BASH_REMATCH[1]}/pull/${BASH_REMATCH[2]}"
    elif [[ "$ref" =~ github\.com/[^/]+/[^/]+/pull/[0-9]+ ]]; then
      echo "${BASH_REMATCH[0]}"
    else
      echo "not a PR: $ref ($usage)" >&2
      exit 2
    fi
  done)
fi

# Rows print after the loop, so a stacked PR can check the PR it sits on.
rows=() branches=()
declare -A own base_of num_of stale_note

while read -r url; do
  repo=$(cut -d/ -f2-3 <<<"$url")
  n=$(cut -d/ -f5 <<<"$url")

  pr=$(gh pr view "$n" --repo "$repo" --json state,isDraft,baseRefName,headRefName,headRefOid,mergeable,mergeCommit,statusCheckRollup)
  state=$(jq -r '.state | ascii_downcase' <<<"$pr")
  if [ "$state" = merged ]; then
    rows+=("$(printf '#%-6s merged   %s' "$n" "$(jq -r '.mergeCommit.oid[0:8]' <<<"$pr")")")
    branches+=("")
    continue
  fi

  ci=$(jq -r '
    [.statusCheckRollup[]? | {name: (.name // .context), c: (.conclusion // .state // ""), s: (.status // "")}] as $all
    | ($all | map(select(.c == "FAILURE" or .c == "ERROR" or .c == "CANCELLED" or .c == "TIMED_OUT")) | map(.name)) as $bad
    | ($all | map(select(.s == "IN_PROGRESS" or .s == "QUEUED" or .s == "PENDING" or .c == "PENDING")) | length) as $pending
    | if ($all | length) == 0 then "CI none yet"
      elif ($bad | length) > 0 then "CI FAIL " + ($bad | join(","))
      elif $pending > 0 then "CI \($pending) pending"
      else "CI ok" end' <<<"$pr")

  summary=$(gh api "repos/$repo/issues/$n/comments" --paginate \
      -q '[.[] | select(.user.login | test("greptile"; "i"))] | last | .body // ""')
  score=$(grep -oE 'Confidence Score: [0-9]/5' <<<"$summary" | head -1 | sed 's/Confidence Score: //' || true)
  # The score belongs to the commit the summary reviewed, which may be older than the head.
  reviewed=$(grep -oE 'Last reviewed commit:.*/commit/[0-9a-f]{7,40}' <<<"$summary" | grep -oE '[0-9a-f]{7,40}$' | head -1 || true)
  open=$(gh api graphql -F owner="${repo%/*}" -F name="${repo#*/}" -F n="$n" -f query='
      query($owner:String!,$name:String!,$n:Int!){ repository(owner:$owner,name:$name){ pullRequest(number:$n){
        reviewThreads(first:100){ nodes{ isResolved comments(first:1){ nodes{ author{login} } } } } } } }' \
    -q '[.data.repository.pullRequest.reviewThreads.nodes[]
         | select(.isResolved | not)
         | select(.comments.nodes[0].author.login | test("greptile"; "i"))] | length')

  base=$(jq -r .baseRefName <<<"$pr")
  head=$(jq -r .headRefOid <<<"$pr")
  mergeable=$(jq -r .mergeable <<<"$pr")
  # GitHub computes mergeability on the first request and answers UNKNOWN until it is done.
  if [ "$mergeable" = UNKNOWN ]; then
    sleep 3
    mergeable=$(gh pr view "$n" --repo "$repo" --json mergeable -q .mergeable)
  fi
  stale=""
  if [ -n "$score" ] && [[ "$head" != "$reviewed"* || -z "$reviewed" ]]; then
    stale="${reviewed:0:8}"
    score="$score stale@$stale"
  fi
  behind=$(gh api "repos/$repo/compare/$base...$head" -q .behind_by 2>/dev/null || echo "?")

  # A 4/5 with every thread closed counts as 5/5, even when the score belongs to an older commit.
  if [ "$(jq -r .isDraft <<<"$pr")" = true ]; then why="draft"
  elif [[ "$ci" == "CI FAIL"* ]]; then why="CI FAIL"
  elif [ "$ci" != "CI ok" ]; then why="$ci"
  elif [ -z "$score" ]; then why="no Greptile score"
  elif [ "${score%%/*}" -lt 4 ]; then why="Greptile ${score%% *}"
  elif [ "$open" -gt 0 ]; then why="$open Greptile threads open"
  elif [ "$mergeable" != MERGEABLE ]; then why="mergeable $mergeable"
  else why=""
  fi

  branch=$(jq -r .headRefName <<<"$pr")
  own[$branch]=$why
  base_of[$branch]=$base
  num_of[$branch]=$n
  stale_note[$branch]=${stale:+(score @$stale)}
  rows+=("$(printf '#%-6s %-8s →%-24s %s  %-34s Greptile %-19s %s open  %-11s %s behind' \
    "$n" "$state" "$base" "${head:0:8}" \
    "$ci" "${score:--}" "$open" "$mergeable" "$behind")")
  branches+=("$branch")
done <<<"$urls"

for i in "${!rows[@]}"; do
  branch=${branches[$i]}
  if [ -z "$branch" ]; then
    echo "${rows[$i]}"
    continue
  fi
  why=${own[$branch]}
  b=${base_of[$branch]}
  while [ -z "$why" ] && [ -n "${num_of[$b]+set}" ]; do
    [ -n "${own[$b]}" ] && why="base #${num_of[$b]} not ready"
    b=${base_of[$b]}
  done
  if [ -n "$why" ]; then ready="no: $why"; else ready="yes ${stale_note[$branch]:-}"; fi
  echo "${rows[$i]}  READY ${ready% }"
done

# A retro gives every signal an outcome; the rest are signals no retro has looked at.
signals="$(dirname "$loop")/signals.md"
if [ -n "$loop" ] && [ -f "$signals" ]; then
  pending=$(grep -E '^- ' "$signals" | grep -cvE '\[(used|dup|dropped)' || true)
  echo "signals: $pending without outcome"
fi
