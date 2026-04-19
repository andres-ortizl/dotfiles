# Single-issue mode (`single <ref>`)

When the user has backlogged plans from a previous run and just wants to dispatch one at a time, or when a specific Sentry issue demands focused attention:

```
/sentry-fix single <ref>
```

Where `<ref>` is **one** of:

| Form | Example | Behavior |
|---|---|---|
| Raw Sentry numeric ID | `110823769` | Look up issue metadata from Sentry, find/create the plan |
| Sentry issue URL | `https://anyformat.sentry.io/issues/110823769/` | Parse ID from path, same as above |
| GH issue URL | `https://github.com/<owner>/<repo>/issues/3118` | Read the GH issue body, extract the Sentry ID from the `**Sentry:**` line, then same as above |
| Plan path | `~/.spec/anyformat-backend/sentry-fix-110823769/plan.md` | Use the plan as-is, skip triage entirely |

## Flow in single-issue mode

1. **Still run Stage -1 (reconcile)** — cheap, high value, and you want the celebrations for anything that merged since last run. Don't skip this. See `reconcile.md`.
2. **Skip Stage 0 (changelog scan)** — you already know which issue you're targeting; scanning the changelog for unrelated issues wastes time.
3. **Skip Stage A (triage)** — if a plan already exists at `~/.spec/<project-name>/sentry-fix-<issue-id>/plan.md`, use it. If not, run ONE Explore agent on just this issue to produce a plan (mini-triage of one).
4. **Skip the gate and raffle decisions** — single-issue mode always dispatches. The user invoking single mode is explicitly overriding the H+M DM-for-approval gate.
5. **Run Stage B for exactly one issue** — worktree + zellij pane + `/spec --auto-approve <plan>` (see `dispatch.md`).
6. **Run the raffle for one PR** and post Message 2 (the playful review announcement) tagging one reviewer. No dashboard list, no batch counts — just this PR.
7. **No batch summary** — single-issue mode does not pollute `#tech` with cycle-start/end announcements. It goes straight to Message 2 once the PR is green.

## Plan resolution priority

When resolving `<ref>` to a plan, try in order:

1. If `<ref>` is a path ending in `.md` and the file exists → use it directly.
2. Extract the Sentry numeric ID from `<ref>` (path, URL, or bare number).
3. Look for `~/.spec/<project-name>/sentry-fix-<id>/plan.md` → use it if exists (backlogged plans from earlier runs land here).
4. Look for an open GH issue in the current repo with title matching `[Sentry * <short-id>]` and a `plan file:` line pointing at an on-disk path → use that.
5. If nothing found, run a one-shot Explore agent to generate a plan from scratch, write it to `~/.spec/<project-name>/sentry-fix-<id>/plan.md`, then dispatch.

## When to prefer single-issue over full-cycle

- You have backlogged plans from a previous `/sentry-fix` run (typical: plans exist but weren't dispatched under the K=3 cap).
- A specific Sentry issue is on fire and you want to skip the triage-the-world cost.
- You want to dispatch a gated H+M issue after making a manual decision on the architectural question.
- You want to re-roll the reviewer raffle for a single PR without affecting others.

Full-cycle is still the right mode when you're doing regular Sentry grooming and want the dedup/cluster/changelog-scan benefits.
