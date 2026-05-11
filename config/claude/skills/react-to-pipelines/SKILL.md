---
name: react-to-pipelines
description: Address failing CI checks on the current PR — group failures by root cause, fix locally, push, then watch the re-run. Pairs with react-to-greptile (comments) for full PR clean-up.
triggers:
  - react to pipelines
  - fix CI
  - address pipeline failures
  - pipeline failures
  - ci failing
  - ci is red
---

# React to Pipeline Failures

Get the current PR's CI green: read every failing check, group by root cause, fix locally, push, then watch the re-run. Loop until checks pass or every remaining failure is explicitly out of scope.

**Scope:** CI/CD failures only (GitHub Actions checks, required status checks). Greptile/reviewer comments are out of scope — use `react-to-greptile` for that. The two skills are designed to run back-to-back.

---

## Phase 1: Find the PR

Determine the current PR from context or branch name:

```bash
gh pr view --json number,url,headRefName,baseRefName,statusCheckRollup
```

Store the PR number and derive `<owner>/<repo>` from the URL (the local remote may have been renamed). The `statusCheckRollup` is your first signal — if it's all `SUCCESS`, you're done before you started.

---

## Phase 2: List Failing Checks

Use `gh pr checks` for the human-readable table, then `gh api` for structured data you can actually filter:

```bash
gh pr checks <number> --repo <owner>/<repo>
```

```bash
gh api "/repos/<owner>/<repo>/commits/<head-sha>/check-runs" --paginate \
  --jq '[.check_runs[] | select(.conclusion == "failure" or .conclusion == "timed_out" or .conclusion == "cancelled")
           | {name, id, conclusion, html_url, details_url, started_at, completed_at}]'
```

Get `<head-sha>` from `gh pr view --json headRefOid`. Filter on `failure` / `timed_out` / `cancelled` — `neutral` and `skipped` are not failures. For each failing check, note `name`, `id`, and `html_url` (the run page).

**Map check-runs to workflow runs** (you need the run ID to pull logs):

```bash
gh run list --branch <head-ref-name> --repo <owner>/<repo> --limit 20 \
  --json databaseId,name,conclusion,headSha,workflowName,createdAt
```

Filter by `headSha == <head-sha>` and `conclusion == "failure"`. The `databaseId` is the run ID for `gh run view`.

---

## Phase 3: Pull Failed Logs

For each failing run, pull only the failed step logs — full logs are massive and mostly green output:

```bash
gh run view <run-id> --repo <owner>/<repo> --log-failed | head -500
```

Cap at ~500 lines per run; tail and head as needed. Tracebacks and assertion failures live in the last ~50 lines of a failed step most of the time.

If `--log-failed` returns nothing (some workflows fail before any step runs, e.g. setup errors), fall back to:

```bash
gh run view <run-id> --repo <owner>/<repo> --log | tail -200
```

For matrix jobs, the relevant matrix leg appears in the log header (`<job-name> (<matrix-key>)`). Identify which leg(s) failed before reading further.

---

## Phase 4: Triage by Root Cause

Group failures by root cause, NOT by check name. One bad import or schema change routinely fails 5+ jobs — fixing the cause once clears all of them.

For each distinct root cause, pick one bucket:

1. **Flake.** Test passes locally, no code change explains it, prior runs on the same SHA were green, or the failure is a known-flaky integration (network, race, etc.). Re-run only — do not edit code:
   ```bash
   gh run rerun <run-id> --failed --repo <owner>/<repo>
   ```
   Then jump to Phase 7. Use sparingly — re-running reds without diagnosing is how green dashboards hide real bugs.

2. **Real failure.** The code on HEAD genuinely breaks the check. Proceed to Phase 5.

3. **Infra / external / out of scope.** External service down, GitHub Actions outage, a check that's known-broken on this branch for unrelated reasons. Note the reason and the run URL. You'll surface these explicitly in the final reply rather than silently leaving them red.

No silent skips. Every failing check must land in one of these three buckets.

---

## Phase 5: Fix Locally

For each bucket (2) root cause:

- **Lint / formatting failures** (ruff, black, etc. on a Python project) — run `/python-hygiene` and let it autofix. Stage the result.
- **Type-check failures** (ty, mypy, pyright) — run `/python-hygiene` first; fix anything it surfaces but can't autofix.
- **Test failures** — reproduce locally with `/run-tests` (anyformat monorepo) or the project's native runner. If the failure is a genuine behavioral bug with no existing test coverage, write the failing test first (RED → GREEN). Do NOT delete or `@pytest.mark.skip` a failing test to turn CI green — that's bucket (3), not (2).
- **Build / dependency failures** — for missing/wrong Python deps use `uv add` / `uv remove` so `uv.lock` stays in sync. Never hand-edit `pyproject.toml`.

Rules:
- Smallest change that resolves the failure
- Follow existing code style
- No new dependencies without approval
- If the "fix" requires deleting the test or weakening the assertion, stop and move the item to bucket (3) with reasoning

Re-run the affected suite locally before committing. Don't push speculative fixes — burns CI minutes and pollutes the run history.

---

## Phase 6: Commit and Push

Skip this phase entirely if every failure was bucket (1) or (3) — nothing to commit. Re-runs in (1) are kicked off in Phase 4; bucket (3) gets surfaced in Phase 7.

Otherwise, prefer a single commit referencing the failing checks:

```bash
git add <changed files>
git commit -m "$(cat <<'EOF'
fix: address CI failures

- <one-line per root cause, e.g. "import path for new serializer (tests-py3.11, tests-py3.12)">
- <another>
EOF
)"
git push
```

Note the short SHA — you'll need it in Phase 7.

---

## Phase 7: Watch the Re-Run

Wait for the new run on the pushed SHA (or the re-run kicked off in Phase 4 bucket (1)) to start, then watch it:

```bash
gh run watch <run-id> --repo <owner>/<repo> --exit-status
```

`--exit-status` makes the command exit non-zero on failure, which is the cleanest signal for the loop below. If you don't yet have a new run ID:

```bash
gh run list --branch <head-ref-name> --repo <owner>/<repo> --limit 5 \
  --json databaseId,headSha,status,conclusion,createdAt --jq '.[0]'
```

**Loop back if still red:** if the new run fails, return to Phase 3 for the still-failing checks. Cap at 3 fix-and-push cycles per skill invocation — if checks are still red after 3 attempts, stop and report. Endlessly pushing speculative fixes is worse than stopping and asking.

**When everything green (or only bucket (3) remains):** post a single PR-level comment summarising what was fixed and what was left out of scope:

```bash
gh pr comment <number> --repo <owner>/<repo> --body "$(cat <<'EOF'
CI addressed.

Fixed:
- <root cause 1> — <one-line> (<sha>)
- <root cause 2> — <one-line> (<sha>)

Not actionable here:
- <check name> — <reason> (<run-url>)
EOF
)"
```

Omit the "Not actionable" section if every failure was fixed. Omit the comment entirely if Phase 5/6 didn't run (pure flakes that re-ran green).

---

## Rules

- **Group by root cause, not by check name.** A single fix often clears multiple reds. Treating each check as independent leads to duplicated diagnosis and inflated fix lists.
- **Don't blindly re-run reds.** Bucket (1) requires evidence the failure is flaky — a passing local run, a prior green run on the same SHA, or a known-flaky integration. Re-running "until it goes green" hides real bugs and burns minutes.
- **Don't disable failing tests or weaken assertions to make CI green.** A skip with no follow-up is bucket (3) with a deceptive label. If the test is wrong, that's a real failure (bucket 2) and the fix is to change the test deliberately. If the underlying behavior is intentionally changing, update the test AND note it in the commit message.
- **Use `--log-failed` first.** Full logs are mostly noise. Only fall back to `--log` when `--log-failed` returns empty (setup failures, cancelled jobs).
- **Cap the loop at 3 cycles.** If three rounds of fixes haven't turned CI green, the diagnosis is wrong — stop and hand back to the user.
- **Pair with `react-to-greptile`.** Run pipelines first (you need CI green for reviewers anyway), then comments. Doing them in the other order means a fresh CI run after every comment fix.
- **Infer `<owner>/<repo>` from `gh pr view --json url`** — don't trust the local remote's slug.
