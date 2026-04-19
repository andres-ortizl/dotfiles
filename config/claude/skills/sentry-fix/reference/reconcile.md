# Stage -1: Reconcile merged sentry-fix PRs from previous runs

**Run this first — before Stage 0, before triage, before anything.** Previous cycles dispatch PRs that merge to `dev` on human timelines (hours to days), long after the `/sentry-fix` conversation that produced them has ended. There is no realistic way to poll from inside the original run — `ScheduleWakeup` tops out at an hour and no conversation survives 72h idle. Instead: at the **start** of every `/sentry-fix` invocation, reconcile what merged since last time.

## The reconcile query

```bash
gh pr list \
  --repo <owner>/<repo> \
  --state merged \
  --label sentry \
  --base dev \
  --json number,headRefName,mergeCommit,body,title,mergedAt \
  --limit 100
```

The `sentry` label is the reliable filter — branch-prefix filtering (`--head "sentry-fix/*"`) is unreliable when sub-sessions name branches slightly differently. Label is authoritative.

## Extract Sentry issue IDs from each merged PR

For each merged PR, gather the full set of Sentry issue IDs it closes:

1. **Primary ID**: parse from the branch name (`sentry-fix/<issue-id>` → `<issue-id>`).
2. **Duplicate IDs**: parse from the PR body. Every sentry-fix plan's `## Sentry metadata` section lists the cluster: `sentry_issue_id:` and `duplicate_ids: [a, b, c]`. When generating PR bodies during Stage B, ensure the plan metadata is included verbatim in the PR description — that's what makes Stage -1 able to find the duplicates later. Grep the body for `sentry_issue_id:` and `duplicate_ids:`, collect both.
3. **Fallback**: if the PR body doesn't have the metadata block (older PR from before this convention), fall back to the primary ID only. Don't fail the run.

## Resolve only what's still unresolved

For each collected issue ID:

1. Query Sentry's current status:
   ```bash
   curl -s "https://sentry.io/api/0/organizations/$SENTRY_ORG/issues/$id/" \
     -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
     | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))"
   ```
2. If status is already `resolved`, skip — nothing to do, don't post again (prevents double-celebration).
3. If still `unresolved`, PUT to resolve (see `sentry-api.md` for the exact call) and post `:white_check_mark: Resolved` to `#tech`:
   ```
   :white_check_mark: *[sentry-fix]* Resolved — <title>
   >*Sentry:* <issue URL>    *PR:* <merged PR URL>
   ```

## Dedupe across a single reconcile pass

A single PR can close multiple Sentry issues (cluster). Post one `:white_check_mark:` per issue (user perspective: each Sentry alert deserves its own closure), but attribute them all to the same PR URL — don't post N separate celebrations for the same merge if users expect one notification. If that becomes noisy, batch the cluster into one post:

```
:white_check_mark: *[sentry-fix]* Resolved via <PR link> — <title> + <N> related
>*Sentry:* <issue URL 1>, <issue URL 2>, ...
```

## Reconcile budget

Cap `gh pr list` at the 50 most-recently-merged PRs with the `sentry` label. Anything older is either (a) already resolved in Sentry or (b) so stale that re-posting a celebration would be noise. The 50-PR cap is effectively "reconcile whatever happened since the last run" for any reasonable cadence.

## Side effect: the old polling-based Stage C is DEAD

There is no Stage C polling loop anymore. Do NOT schedule wakeups to check for merges. The reconcile happens exclusively at Stage -1 of the **next** run. Between runs, merged PRs accumulate silently — that's fine, they'll be picked up whenever the user next invokes `/sentry-fix`.

---

# Stage 0: Scan changelog for already-shipped fixes

**Run this BEFORE triage.** Any Sentry issue whose error is already fixed in a recent changelog entry should be marked `resolved` in Sentry immediately — triaging an already-fixed issue is wasted work and produces misleading plans.

1. Read the repo-root `CHANGELOG.md` (NOT `anyformat/docs/changelog/overview.mdx` — that one is a coarse customer-facing summary without PR links or error keywords). The repo-root file has PR numbers and specific error strings and is the searchable source of truth.

2. For each unresolved Sentry issue, grep the changelog for keywords from the error title / top stack frame. Examples from past runs:
   - `corrupt or empty PDF` → matched "Handle corrupt PDF hydration gracefully" (PR #3068)
   - `coroutine 'GlobalAuth.authenticate' was never awaited` → matched "Fix v3 auth coroutine warnings" (PR #3070)
   - `async_to_sync was passed a non-async-marked callable` → same PR

3. When a clear match is found (changelog entry describes a fix for the exact error), verify the fix in code with a quick `Grep`. If confirmed, mark the Sentry issue resolved via the org-scoped endpoint (see `sentry-api.md`).

4. Report in the run header: "Pre-resolved N issues from changelog scan: BACKEND-X, CORE-Y, ..."

This step typically closes 2–5 issues per run and prevents embarrassing triage reports for things already shipped.
