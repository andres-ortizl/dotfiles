---
name: react-to-greptile
description: Address Greptile PR review comments — read inline comments and summary, fix issues locally, push, reply to each thread, then tag Greptile to re-score and resolve threads.
triggers:
  - react to greptile
  - address greptile
  - greptile comments
  - respond to greptile
---

# React to Greptile Review

Address all Greptile review feedback on the current PR: fix every issue, reply to each thread with what changed, then ask Greptile to re-score.

---

## Phase 1: Find the PR

Determine the current PR from context or branch name:

```bash
gh pr view --json number,url,headRefName
```

Store the PR number for all subsequent API calls. Detect the repo (may differ from local remote if the repo was renamed/moved):

```bash
gh pr view <number> --json url
```

---

## Phase 2: Read All Greptile Feedback

Fetch both sources — the summary comment AND inline thread comments. Do NOT skip either.

**Inline review comments:**
```bash
gh api repos/<owner>/<repo>/pulls/<number>/comments
```

Filter to comments where `user.login` contains `greptile`. Extract for each:
- `id` — needed to reply
- `path` — file
- `body` — the issue raised
- `diff_hunk` — surrounding code context

**PR-level summary comment:**
```bash
gh pr view <number> --comments
```

Find the Greptile summary block (starts with `### Greptile Summary` or `<h3>Greptile Summary</h3>`). Read it fully — **the summary frequently raises issues (e.g. threshold inconsistencies, missing edge-case handling) that do NOT appear as inline comments.** Treat it as an equal source to inline threads, not a secondary one.

---

## Phase 3: Triage All Issues

**Start with the summary.** Extract every actionable item from it before looking at inline threads. Then merge with inline items.

List every actionable item from both sources. For each:

1. Read the relevant file(s)
2. Decide: fix now, or explain why it's intentional / out of scope
3. Group fixes that touch the same file

Do NOT skip anything without a reason.

---

## Phase 4: Fix Locally

Implement all fixes. Rules:
- Smallest change that resolves the issue
- Follow existing code style
- No new dependencies without approval
- If a suggestion conflicts with the codebase design, note it but don't blindly apply it
- **Dependency changes:** use `uv add` / `uv remove` instead of hand-editing `pyproject.toml` — this keeps `uv.lock` in sync automatically

Run tests after fixing using the `/run-tests` skill to run tests for affected packages. Do NOT include markers like `-m llm` or `-m slow` — only run the default test suite.

**If Greptile flagged a bug or edge case with no existing test coverage:** write a test that reproduces the issue before fixing it (TDD: RED → GREEN). Do not fix without a test if the issue is behavioral — untested fixes can regress silently.

---

## Phase 5: Commit and Push

```bash
git add <changed files>
git commit -m "fix: address greptile review comments"
git push
```

Note the short commit SHA — you'll reference it in every reply.

---

## Phase 6: Reply to Every Inline Thread

For each Greptile inline comment, post a reply using:

```bash
gh api repos/<owner>/<repo>/pulls/<number>/comments/<id>/replies \
  -X POST \
  -f body="Fixed in <sha> — <one-line description of what changed>."
```

For issues intentionally not addressed:
```bash
-f body="Intentional — <brief reason>."
```

Every thread must get a reply. No silent skips.

---

## Phase 7: Tag Greptile for Re-Review

Post a single PR-level comment tagging Greptile:

```bash
gh pr comment <number> --repo <owner>/<repo> \
  --body "@greptile-apps All comments addressed in <sha>. Please re-review each inline thread — resolve the ones that are fixed, and comment on any that are not. Then re-score."
```

---

## Rules

- **The summary comment is not optional.** Always read it before fixing anything — it is where Greptile puts score rationale and issues that didn't fit inline. Missing it means fixing only half the feedback and getting the same low score again.
- **Summary-only items need replies too.** Issues raised in the summary but without inline threads have no thread to reply to. Include them explicitly in the Phase 7 re-review comment so Greptile (and reviewers) can see they were addressed.
- Reply to **every** greptile thread, even ones you disagree with — silence looks like oversight
- Use the monorepo repo slug in all API calls (the remote may have been renamed)
- If the repo slug is uncertain, infer it from `gh pr view --json url`
- Commit SHA references in replies let reviewers jump straight to the diff
- Do not push multiple commits if one is enough — keep the history clean
