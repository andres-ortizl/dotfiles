#!/usr/bin/env bash
# One line per PR: state, base, head, CI, review bot, mergeability.
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

while read -r url; do
  repo=$(cut -d/ -f2-3 <<<"$url")
  n=$(cut -d/ -f5 <<<"$url")

  pr=$(gh pr view "$n" --repo "$repo" --json state,baseRefName,headRefOid,mergeable,mergeCommit,statusCheckRollup)
  state=$(jq -r '.state | ascii_downcase' <<<"$pr")
  if [ "$state" = merged ]; then
    printf '#%-6s merged   %s\n' "$n" "$(jq -r '.mergeCommit.oid[0:8]' <<<"$pr")"
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
  if [ -n "$score" ] && [[ "$head" != "$reviewed"* || -z "$reviewed" ]]; then
    score="$score stale@${reviewed:0:8}"
  fi
  behind=$(gh api "repos/$repo/compare/$base...$head" -q .behind_by 2>/dev/null || echo "?")

  printf '#%-6s %-8s →%-24s %s  %-34s Greptile %-19s %s open  %-11s %s behind\n' \
    "$n" "$state" "$base" "${head:0:8}" \
    "$ci" "${score:--}" "$open" "$(jq -r .mergeable <<<"$pr")" "$behind"
done <<<"$urls"

# A retro gives every signal an outcome; the rest are signals no retro has looked at.
signals="$(dirname "$loop")/signals.md"
if [ -n "$loop" ] && [ -f "$signals" ]; then
  pending=$(grep -E '^- ' "$signals" | grep -cvE '\[(used|dup|dropped)' || true)
  echo "signals: $pending without outcome"
fi
