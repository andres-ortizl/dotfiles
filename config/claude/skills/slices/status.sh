#!/usr/bin/env bash
# One line per PR linked in a loop's loop.md: state, base, head, CI, review bot, mergeability.
# Usage: status.sh <loop dir or loop.md>
set -euo pipefail

loop="${1:?usage: status.sh <loop dir or loop.md>}"
[ -d "$loop" ] && loop="$loop/loop.md"

grep -oE 'github\.com/[^/ ]+/[^/ ]+/pull/[0-9]+' "$loop" | sort -u -t/ -k5,5n | while read -r url; do
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

  score=$(gh api "repos/$repo/issues/$n/comments" --paginate \
      -q '[.[] | select(.user.login | test("greptile"; "i"))] | last | .body // ""' \
    | grep -oE 'Confidence Score: [0-9]/5' | head -1 | sed 's/Confidence Score: //' || true)
  open=$(gh api graphql -F owner="${repo%/*}" -F name="${repo#*/}" -F n="$n" -f query='
      query($owner:String!,$name:String!,$n:Int!){ repository(owner:$owner,name:$name){ pullRequest(number:$n){
        reviewThreads(first:100){ nodes{ isResolved comments(first:1){ nodes{ author{login} } } } } } } }' \
    -q '[.data.repository.pullRequest.reviewThreads.nodes[]
         | select(.isResolved | not)
         | select(.comments.nodes[0].author.login | test("greptile"; "i"))] | length')

  printf '#%-6s %-8s →%-24s %s  %-34s Greptile %-4s %s open  %s\n' \
    "$n" "$state" "$(jq -r .baseRefName <<<"$pr")" "$(jq -r '.headRefOid[0:8]' <<<"$pr")" \
    "$ci" "${score:--}" "$open" "$(jq -r .mergeable <<<"$pr")"
done
