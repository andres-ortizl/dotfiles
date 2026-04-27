---
name: react-to-greptile
description: Address Greptile PR review comments only (inline + summary) — fix issues locally, push, reply to every thread, tag Greptile for re-review. Chains into `react-to-pipelines` afterward so CI is addressed in the same ritual.
triggers:
  - react to greptile
  - address greptile
  - greptile comments
  - respond to greptile
---

# React to Greptile Review

Address all Greptile review feedback on the current PR: fix every *live* issue, reply to each thread with what changed (or cite the SHA that already fixed it), then ask Greptile to re-score.

**Scope:** this skill handles *review comments only* (inline threads + the PR-level summary Greptile posts). CI/CD pipeline failures are out of scope — Phase 8 hands off to `react-to-pipelines` so both are covered in one sitting.

---

## Phase 1: Find the PR

Determine the current PR from context or branch name:

```bash
gh pr view --json number,url,headRefName,baseRefName
```

Store the PR number and derive `<owner>/<repo>` from the URL (the local remote may have been renamed).

---

## Phase 2: Read All Greptile Feedback

Fetch both sources — the summary comment AND inline thread comments. Do NOT skip either.

**Inline review comments** (JSON — easier to parse than text output):

```bash
gh api "/repos/<owner>/<repo>/pulls/<number>/comments" --paginate \
  --jq '[.[] | select(.user.login | ascii_downcase | contains("greptile"))
           | {id, path, body, original_commit_id, in_reply_to_id, diff_hunk}]'
```

Extract `id`, `path`, `body`, `original_commit_id` (the SHA the comment was written against — used in Phase 3), and `diff_hunk` for each.

**PR-level summary comment** (latest only — Greptile re-posts on every review, so old summaries clutter the output):

```bash
gh api "/repos/<owner>/<repo>/issues/<number>/comments" --paginate \
  --jq '[.[] | select(.user.login=="greptile-apps")] | sort_by(.created_at) | last | .body'
```

Parse the latest summary for:
- **Overall score** (e.g. "Confidence Score: 4/5")
- **"Previously-flagged X is now resolved"** lines — these tell you which inline threads are already acknowledged-fixed by Greptile and need a "resolve the thread" reply, not a re-fix.
- **New findings that do NOT appear as inline comments** — the summary is often where Greptile puts issues that span multiple files or don't anchor to a single line (e.g. "test X will fail because payload shape changed").

**If the summary query returns empty**, Greptile may not have scored yet — the inline comments and the summary are posted independently and the summary often lands a minute or two later. Wait ~60s and re-fetch once before declaring "no summary". An empty summary is treated as "no summary findings" — silently skipping a delayed-but-real summary is the most common cause of leaving P1s unaddressed.

Do NOT parse `gh pr view --comments` — that dumps a tab-separated text format with every comment in history, which is fragile and usually contains stale data.

---

## Phase 3: Triage — Three Outcomes per Item

For every inline thread AND every summary-only finding, pick exactly one:

1. **Already fixed on HEAD.** Check the flagged code on the current branch. If the code path no longer exists, or the fix clearly landed in a later commit, find that SHA (`git log --oneline -- <file>` or search commit messages) and note it. **Skip Phase 4** for this item — go straight to Phase 6 with `"Fixed in <sha>."`

2. **Fix now.** The issue still exists on HEAD. Proceed to Phase 4.

3. **Intentional / out of scope.** Note the reason. The reply in Phase 6 explains why.

No silent skips. Every item must land in one of these three buckets. Start with the summary so you triage the "big picture" findings before getting lost in inline detail.

---

## Phase 4: Fix Locally

Implement fixes for items in bucket (2). Rules:

- Smallest change that resolves the issue
- Follow existing code style
- No new dependencies without approval
- If a suggestion conflicts with the codebase design, move the item to bucket (3) — don't blindly apply it
- **Dependency changes:** use `uv add` / `uv remove` instead of hand-editing `pyproject.toml` — keeps `uv.lock` in sync

Run tests after fixing using the `/run-tests` skill for affected packages. Do NOT include markers like `-m llm` or `-m slow` — only the default suite.

**If Greptile flagged a bug or edge case with no existing test coverage:** write a test that reproduces the issue before fixing it (TDD: RED → GREEN). Untested behavioral fixes regress silently.

---

## Phase 5: Commit and Push

Skip this phase entirely if all items were bucket (1) — there's nothing to commit.

Otherwise, prefer a single commit that references the review:

```bash
git add <changed files>
git commit -m "$(cat <<'EOF'
fix: address Greptile review comments

- <one-line per item, e.g. "serializer accepts results_format (P0)">
- <another>
EOF
)"
git push
```

Note the short SHA — you'll reference it in Phase 6.

---

## Phase 6: Reply to Every Inline Thread

For each Greptile inline comment, post a reply. Use `-q '.html_url'` so the 5KB POST response is trimmed to just the reply URL (note: `gh api` rejects `--silent` combined with `-q`/`--jq` — pick one):

```bash
gh api "/repos/<owner>/<repo>/pulls/<number>/comments/<id>/replies" \
  -X POST -q '.html_url' \
  -F body="$(cat <<'EOF'
Fixed in <sha> — <one-line description>.
EOF
)"
```

Reply templates by bucket:

- **(1) Already fixed on HEAD:** `"Fixed in <prior-sha> — <what that commit changed>."`
- **(2) Fixed now:** `"Fixed in <new-sha> — <what changed>."`
- **(3) Intentional:** `"Intentional — <brief reason>."`

**Body escaping:** code references using backticks are common and safe inside a `'EOF'` heredoc (single-quoted delimiter prevents shell expansion). Do NOT use `-f body="... \`foo\` ..."` — zsh/bash command substitution on backticks will break the body or execute arbitrary text from the reply.

Every thread must get a reply. No silent skips.

---

## Phase 7: Tag Greptile for Re-Review

Post a single PR-level comment. Include:

- The SHA that addressed the latest round (or "no code changes, all prior feedback was already resolved on HEAD in <sha>…<sha>" if nothing needed fixing)
- A bullet list of **summary-only findings** and where they were resolved — these have no inline thread to hang a reply on, so they only become visible here
- The request to re-review

```bash
gh pr comment <number> --repo <owner>/<repo> --body "$(cat <<'EOF'
@greptile-apps All feedback addressed. Please re-review each inline thread — resolve the ones that are fixed, comment on any that are not, and re-score.

Summary-only items resolved:
- <summary finding 1> — fixed in <sha>
- <summary finding 2> — resolved on HEAD by <sha> (pre-existing)
EOF
)"
```

Re-tagging `@greptile-apps` on the same PR is safe — Greptile is idempotent; it starts a new review, not a duplicate one.

---

## Phase 7b: Wait for re-review and loop on new findings

The re-tag in Phase 7 triggers a fresh Greptile pass. That pass commonly produces a new summary with findings that did not exist (or were not yet posted) when you ran Phase 2. The skill is **not complete** until you've seen and addressed the re-review.

1. Wait ~2–4 min for Greptile to land its re-review (`ScheduleWakeup(delaySeconds=180-300)`).
2. Re-fetch both inline comments and the latest summary using the same Phase 2 queries. Compare against what you addressed this run — anything new is a fresh finding.
3. If the new summary lists actionable findings (P0/P1/P2) that you did not just fix, **loop back to Phase 3** with them. Repeat Phase 4 → 7 → 7b until a re-review either (a) flags nothing new, or (b) only flags items you've already triaged as bucket (3) intentional.
4. If the new summary is empty or only contains "all previously-flagged items resolved", you're done — proceed to Phase 8.

Bound the loop at 3 iterations. If Greptile keeps surfacing new findings on each pass, something is structurally wrong — pause and ask the user before continuing.

---

## Phase 8: Check Pipelines

Greptile feedback rarely exists in isolation — if the PR is mid-review it almost always also has CI results worth acting on. Hand off to `react-to-pipelines` to catch any failing jobs. The two skills are designed to run back-to-back:

1. If Phase 5 just pushed a new commit, give CI time to start — typically `ScheduleWakeup(delaySeconds=270-480)` before checking, so the first batch of jobs has real status (not `pending`).
2. Then invoke `/react-to-pipelines`. It re-snapshots `gh pr checks`, so it'll work whether CI is still running, already green, or already red.
3. Skip this phase only if the user explicitly asked for Greptile-only work, or if the PR is still a draft with CI disabled.

This keeps the full "PR is clean" ritual in one loop: comments replied to, pipelines green, re-review requested — without the user having to re-invoke for each piece.

---

## Rules

- **Summary + inline are equal sources.** Always read the latest summary before fixing anything. Summary-only items are common and easy to miss; they must appear explicitly in Phase 7.
- **Re-tag triggers a re-review — Phase 7b is mandatory, not optional.** Greptile's re-review can introduce findings that were not visible during Phase 2. Concluding the skill at Phase 7 is the most common way to leave P1s on the table. Wait, re-fetch, loop.
- **Greptile's "pre-existing from earlier rounds" prose can be hallucinated.** When the summary claims an item is "from a prior review round" but the PR has only one review, treat it as a current finding regardless. The framing is wrong; the finding is usually real.
- **"Is this still live?" check before every fix.** Greptile comments target the SHA they were posted against. On a long-lived branch, many will have been superseded. Check HEAD before reaching for the editor — then reply with the resolving SHA, not a duplicate fix.
- Reply to **every** Greptile thread, even ones you disagree with — silence looks like oversight.
- Infer `<owner>/<repo>` from `gh pr view --json url`; don't trust the local remote's slug.
- Commit SHA references in replies let reviewers (and the next skill run) jump straight to the diff.
- Prefer one commit over many when Phase 5 runs — keep history clean. But if fixes already landed across earlier commits, cite each by SHA rather than squashing.
- Use `-q '.html_url'` on `gh api` POST calls to trim the 5KB response to just the reply URL. `--silent` also suppresses the body but cannot be combined with `-q`/`--jq` — `gh api` errors out if you pass both.
- **This skill is comment-scoped; pipelines are Phase 8's job.** Don't start debugging a broken CI job mid-Phase-4 — finish the comment pass, hand off to `react-to-pipelines`, otherwise you'll mingle unrelated fixes into a commit that reads "address Greptile review comments".
