---
name: react-to-pipelines
description: Diagnose and fix failing CI/CD pipelines on the current PR — cluster failures by root cause, fix locally, verify, push, and watch until green.
triggers:
  - react to pipelines
  - fix ci
  - fix failing pipelines
  - check ci
  - ci is red
  - fix the pipeline
---

# React to Pipelines

Diagnose every failing CI job on the current PR, fix the root cause locally, verify, push, and stay until the pipeline is green (or the remaining failures are confirmed flakes/infra out of scope).

Pipeline failures cluster: one root cause (e.g. a migration conflict) commonly breaks 4+ jobs (backend tests + e2e + cypress + anything that boots the backend). Do not fix four symptoms — find the one fault.

---

## Phase 1: Find the PR and snapshot CI status

```bash
gh pr view --json number,url,headRefName,baseRefName
gh pr checks <number> --repo <owner>/<repo>
```

Derive `<owner>/<repo>` from the URL (the local remote may have been renamed). Capture the list of failing jobs and their job IDs — you'll fetch logs by job ID in Phase 2.

If every check is `pass` or `pending`, stop — there is nothing to react to. If some are still `pending`, decide: wait for them (use ScheduleWakeup for 4–10 min), or proceed with the known failures if the pending ones are unrelated.

---

## Phase 2: Pull logs and cluster by root cause

For each failing job, fetch the log and scan for the actual error (skip docker-pull and apt-get noise):

```bash
gh run view <run-id> --log-failed --repo <owner>/<repo> --job <job-id> 2>&1 \
  | grep -iE "error|fail|conflict|traceback|exception" | head -40
```

Group failures by root cause, not by job name. Common clusters:

- **Migration conflict after base merge** — `django.core.management.base.CommandError: Conflicting migrations detected; multiple leaf nodes`. Usually means both base and branch added a migration with the same number. Fix: rebase + renumber. Blast radius: all jobs that boot the backend (backend tests, e2e, cypress, api, anything calling the backend).
- **Stale test payload after refactor** — assertion mismatches where expected and actual differ in a way that matches a recent commit on the branch. Fix: update the test.
- **Container unhealthy** — `container X is unhealthy` with no python traceback often means an upstream service (backend, anyformat-core) failed to start. Look at the logs of *that* service first, not the job that reported the timeout.
- **5xx during cy.request / e2e** — almost always a symptom of backend being broken, not a Cypress problem. Fix the backend, not the test.
- **Type errors / lint failures** — self-explanatory, fix in place.
- **Flaky network / docker pull** — retry once; if it recurs, ignore and proceed.
- **Dependency resolution** — `uv.lock` out of sync after a `pyproject.toml` edit. Fix: `uv sync --all-packages`.

**Write down one sentence per cluster before fixing anything.** "pytest-backend + pytest-e2e-tests + run-cypress all failed because of the same Django migration leaf collision" is a triage output; "4 jobs are red" is not.

---

## Phase 3: Triage — four outcomes per cluster

For each cluster, pick exactly one:

1. **Branch bug — fix in place.** The branch actually broke something. Fix the code or test.
2. **Rebase + renumber.** Branch fell out of date with base; merging introduced a semantic collision (migrations, config keys, dependency pins). Rebase onto base, resolve the collision, renumber/rename as needed.
3. **Flake / infra.** Outside the branch's control. Retry the job once via `gh run rerun <run-id> --failed` and move on. Do NOT mask by adding retries to the test.
4. **Already fixed on HEAD.** Branch has new commits since CI ran; the current HEAD is different from the SHA that failed. Re-trigger CI by pushing an empty commit or `gh run rerun`.

No silent skips. Every cluster lands in one of these buckets.

---

## Phase 4: Fix locally

Apply the fix for bucket (1) or (2):

**Bucket (1) — branch bug.** Smallest change. Follow the repo's existing style. If the fix is behavioral, write a failing test first (TDD). Run `/run-tests` for the affected package(s) before committing.

**Bucket (2) — rebase + renumber.** This is the only risky path:

1. **Check for uncommitted work first** — `git status`. Rebase refuses if the tree is dirty; don't stash without telling the user.
2. **Fetch base** — `git fetch origin <base>`.
3. **Rebase** — `git rebase origin/<base>`.
4. **Resolve collisions.** File-level conflicts are rare; semantic collisions are the usual case:
   - **Django migrations:** rename the branch's migrations to continue from base's new leaf, and update each file's `dependencies = [...]`. Rename from highest number down to avoid overwriting existing files.
   - **Config / enum additions:** if both sides added the same key, pick one or merge.
   - **Dependency pins:** `uv sync --all-packages` after merging.
5. **Verify locally** — re-run the test suite that originally failed. If the fix was a rebase+renumber, run the full affected package (not just one file), because the collision may have been caught at migration-load time which runs before every test.

---

## Phase 5: Commit and push

**Bucket (1) — non-rebase fix.** Regular commit + `git push`:

```bash
git add <files>
git commit -m "fix: <one-line root cause>"
git push
```

**Bucket (2) — rebase.** The push rewrites branch history. STOP and confirm with the user before force-pushing. Once authorized:

```bash
git push --force-with-lease
```

`--force-with-lease` refuses the push if the remote moved since your last fetch — safer than bare `--force`. Never use `--force` on a shared branch without explicit approval.

For sensitive branches (anything merged to by multiple people, release branches, `main`/`dev`), do not rebase even if asked — propose a merge commit instead.

---

## Phase 6: Watch CI until resolved

Push triggers a new CI run. Schedule a check for when the slowest previously-failing job is expected to complete (typically 4–8 min):

```
ScheduleWakeup(delaySeconds=270-480, prompt="Check gh pr checks <number> on <owner>/<repo>; report status")
```

On wake-up:

- **All green** — report success with the resolving SHA. Done.
- **New failures** — go back to Phase 2 with the new cluster.
- **Same cluster still failing** — the fix was incomplete. Pull logs, refine, repeat.
- **Still pending** — schedule another wakeup. Don't burn cache polling every 60s.

---

## Rules

- **Cluster first, fix second.** Four red jobs with one root cause is one fix, not four. Write down the clusters before touching any file.
- **Don't fix symptoms.** Cypress 500s on `cy.request` almost never mean "fix Cypress" — fix what the backend is returning 500 for. E2e "container unhealthy" is the reporter, not the cause.
- **Grep the log, don't read it top-to-bottom.** CI logs are 90% docker pulls and 10% signal. `grep -iE "error|fail|conflict|traceback|exception"` gets you to the signal.
- **Rebase needs consent.** The skill may *recommend* a rebase when it's the clear fix, but the force-push always pauses for user approval.
- **Use `--force-with-lease`, never bare `--force`** on a branch the user has pushed before.
- **"CI was red yesterday" is not evidence CI is red now.** Always re-snapshot with `gh pr checks` before acting — the user may have pushed in the interim, or flakes may have resolved.
- **Commit messages say what and why, not "fix CI".** `fix: renumber migrations to follow dev's 0154` is useful; `fix: pipelines` is not.
- **Known-flaky job = one retry, not a fix.** If the first retry also fails, it's not flaky — keep investigating.
