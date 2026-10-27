---
name: react-to-greptile
description: Address Greptile PR review comments - read the review threads and summary, fix issues locally, push, reply to and resolve each thread, then re-trigger Greptile and wait for the new verdict. Uses the Greptile MCP server when it is connected, and gh otherwise.
triggers:
  - react to greptile
  - address greptile
  - greptile comments
  - respond to greptile
---

# React to Greptile Review

Address all Greptile feedback on the current PR: fix every *live* issue, reply to each thread with what changed (or cite the SHA that already fixed it), resolve what is fixed, then re-trigger Greptile and read the new verdict.

Two facts shape every phase:

- **Thread state lives only in GitHub GraphQL** (`isResolved`, `isOutdated`). A REST review comment's `commit_id` advances to the PR tip, so it makes a stale finding look current. Never decide "open" or "fixed" from REST.
- **A review is done when the `Greptile Review` check run on the pushed SHA completes.** The summary comment's "Last reviewed commit" can lag behind; do not infer completion from it.

---

## Phase 0: Pick the method - load ONE reference

1. Look for Greptile MCP tools (`mcp__greptile__*`). If they are deferred, load them with `ToolSearch("+greptile")`.
2. If they exist, call `mcp__greptile__get_me`. A result with an organization means the MCP is connected and signed in.
3. Read exactly one reference and use it for the steps marked **[method]** below:
   - MCP connected and signed in: [`references/mcp.md`](references/mcp.md)
   - Otherwise (not installed, not signed in, or an auth error): [`references/gh.md`](references/gh.md)

Do not read both. If an MCP call fails with an auth error mid-run, switch to `references/gh.md` for the remaining steps.

---

## Phase 1: Find the PR

```bash
gh pr view --json number,url,headRefName,baseRefName,headRefOid
```

Derive `<owner>/<repo>` from the URL (the local remote may have been renamed). Store `REPO=<owner>/<repo>` and the PR number.

---

## Phase 2: Read all Greptile feedback

Read both sources. Do NOT skip either.

**Review threads (GraphQL, both methods):**

```bash
gh api graphql -F owner=<owner> -F name=<repo> -F n=<number> -f query='
query($owner:String!,$name:String!,$n:Int!){
  repository(owner:$owner,name:$name){ pullRequest(number:$n){
    reviewThreads(first:100){ nodes{
      id isResolved isOutdated path line
      comments(first:1){ nodes{ author{login} body originalCommit{oid} } }
    } }
  } }
}' -q '.data.repository.pullRequest.reviewThreads.nodes[]
       | select(.comments.nodes[0].author.login | test("greptile";"i"))
       | select(.isResolved | not)
       | {id, isOutdated, path, line, commit: .comments.nodes[0].originalCommit.oid[0:7], body: .comments.nodes[0].body}'
```

Keep the thread `id` (`PRRT_...`): Phase 6 replies and resolves through it.

**Latest review summary and score - [method] "Read the summary".** Parse it for:

- **Overall score** (e.g. "Confidence Score: 4/5") and the commit it names.
- **"Previously-flagged X is now resolved"** lines: those threads need a reply and a resolve, not a re-fix.
- **Summary-only findings**: issues that span files and have no inline thread. They are easy to miss.

---

## Phase 3: Triage - three outcomes per item

For every open thread AND every summary-only finding, pick exactly one:

1. **Already fixed on HEAD.** The flagged code path no longer exists, or a later commit fixed it, possibly in a different file than the thread's anchor. Find that SHA (`git log --oneline -- <file>`). Skip Phase 4 for this item.
2. **Fix now.** The issue still exists on HEAD. Go to Phase 4.
3. **Intentional / out of scope.** Note the reason. Cite the doc or ADR when one decides it; a well-evidenced reply does make Greptile withdraw a finding.

No silent skips. Start with the summary so you triage the big-picture findings first. `isOutdated: true` means the anchored lines changed; it does not mean the issue is fixed.

---

## Phase 4: Fix locally

Implement fixes for bucket (2):

- Smallest change that resolves the issue. Follow existing code style.
- No new dependencies without approval. Use `uv add` / `uv remove`, never hand-edit `pyproject.toml`.
- If a suggestion conflicts with the codebase design, move the item to bucket (3).
- If Greptile flagged a bug with no test coverage, write the failing test first (RED, then GREEN).

Run the affected tests with the `/run-tests` skill, default suite only (no `-m llm` or `-m slow`).

---

## Phase 5: Commit and push

Skip if every item is bucket (1) or (3).

```bash
git add <changed files>
git commit -m "$(cat <<'EOF'
fix: address Greptile review comments

- <one line per item>
EOF
)"
git push
```

Note the short SHA for Phase 6.

---

## Phase 6: Reply to every thread, resolve the fixed ones

Reply through the thread id (both methods):

```bash
gh api graphql -F id=<PRRT_id> -f body="$(cat <<'EOF'
Fixed in <sha> - <one-line description>.
EOF
)" -f query='mutation($id:ID!,$body:String!){
  addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$id, body:$body}){ comment{ url } } }' \
  -q '.data.addPullRequestReviewThreadReply.comment.url'
```

Reply templates:

- **(1) Already fixed:** `Fixed in <prior-sha> - <what that commit changed>.`
- **(2) Fixed now:** `Fixed in <new-sha> - <what changed>.`
- **(3) Intentional:** `Intentional - <reason, with the doc or ADR path>.`

Then resolve the threads in buckets (1) and (2), several per call:

```bash
gh api graphql -f query='mutation{
  t1: resolveReviewThread(input:{threadId:"<PRRT_id_1>"}){ thread{ isResolved } }
  t2: resolveReviewThread(input:{threadId:"<PRRT_id_2>"}){ thread{ isResolved } }
}'
```

Leave bucket (3) threads open for Greptile or a human to accept.

**Body escaping:** keep backticks inside a `<<'EOF'` heredoc (the quoted delimiter stops shell expansion). Never put them in a double-quoted `-f body="..."` literal.

---

## Phase 7: Re-trigger Greptile and read the new verdict

1. **Record the trigger point** before triggering:
   ```bash
   SHA=$(git rev-parse HEAD); SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
   ```
2. **Post the context comment and trigger the review - [method] "Trigger a review".** The context comment lists:
   - the SHA that addressed this round (or "no code changes, all feedback was already resolved on HEAD")
   - each **summary-only finding** and where it was resolved; it has no thread to carry a reply
3. **Wait for the review** (both methods). Run the loop with `run_in_background` (the harness blocks a foreground `sleep`):
   ```bash
   for i in $(seq 1 60); do
     RUN=$(gh api "repos/$REPO/commits/$SHA/check-runs?check_name=Greptile%20Review" \
       -q "[.check_runs[] | select(.started_at >= \"$SINCE\")] | first | \"\(.status) \(.conclusion)\"")
     case "$RUN" in completed*) echo "$RUN"; exit 0;; esac
     sleep 20
   done
   echo "timed out after 20 minutes"; exit 1
   ```
   On a timeout, stop and report it. Do not read a stale verdict as the new one.
4. **Read the new verdict - [method] "Read the summary".** Quote the score line and the commit it names. Do not paraphrase it as "green".

If the new review raises findings, run the skill again. Stop after three rounds and report what remains.

---

## Rules

- **Summary and threads are equal sources.** Summary-only items must appear in the Phase 7 context comment.
- **Check "is this still live?" before every fix.** On a long branch many findings were already superseded. Reply with the resolving SHA instead of fixing twice.
- Reply to **every** Greptile thread, even ones you disagree with. Silence looks like oversight.
- Infer `<owner>/<repo>` from `gh pr view --json url`, not from the local remote.
- Every review costs credits (1 Base, 3 Plus, 10 Apex), charged to the PR author. Trigger once per round, never twice.
- Prefer one commit per round. If fixes already landed across earlier commits, cite each SHA rather than squashing.
