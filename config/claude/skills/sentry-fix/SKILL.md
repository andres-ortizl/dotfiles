---
name: sentry-fix
description: "Autonomous Sentry triage and fix loop. Pulls unresolved Sentry issues, investigates each in parallel, auto-dispatches up to 3 high-confidence fixes as spec loops, and resolves issues on merge. Triggers on: sentry fix, fix sentry errors, autofix sentry, sentry autofix."
argument-hint: "[project1,project2] [dry-run] | single <sentry-id|sentry-url|gh-issue-url|plan-path>"
allowed-tools: [Read, Glob, Grep, Bash, Agent, Skill, Edit, Write, Task, ScheduleWakeup, ToolSearch]
---

# Sentry Fix Loop

Autonomous loop: investigate unresolved Sentry issues in parallel, dispatch the top 3 as `spec --auto-approve` loops, resolve on merge. Keeps `#tech` informative, not noisy.

## The Loop

```
User invokes /sentry-fix
        │
        ▼
┌─ PREREQ ────────────────┐    → reference/prereqs.md
│  Load env vars           │
│  Verify Slack #tech      │
│  Verify Sentry token     │
└───────┬──────────────────┘
        ▼
┌─ STAGE -1: Reconcile ────┐    → reference/reconcile.md
│  List merged sentry-     │       reference/sentry-api.md
│  labeled PRs since last  │
│  run; resolve still-     │
│  unresolved Sentry IDs   │
└───────┬──────────────────┘
        ▼
┌─ STAGE 0: Changelog scan ┐    → reference/reconcile.md (same file)
│  Pre-resolve fixes that  │
│  already shipped         │
└───────┬──────────────────┘
        ▼
┌─ STAGE A: Triage ────────┐    → reference/triage.md
│  Fetch ALL unresolved    │
│  Explore agents in       │
│  parallel (one per       │
│  cluster, top 10 only)   │
└───────┬──────────────────┘
        ▼
┌─ RANK & GATE ────────────┐    → reference/ranking.md
│  Top 3 by confidence,    │
│  scope, freq. Gate by    │
│  confidence × scope.     │
│  Gated → GH issues.      │
└───────┬──────────────────┘
        ▼
┌─ STAGE B: Fix (K=3) ─────┐    → reference/dispatch.md
│  One zellij pane per     │       reference/raffle.md
│  auto-dispatchable issue │
│  running /spec           │
│  --auto-approve          │
└───────┬──────────────────┘
        ▼
┌─ CYCLE ANNOUNCEMENTS ────┐    → reference/slack.md
│  Msg 1 (cycle started)   │
│  Msg 2 (PRs ready +      │
│    raffle) after CI      │
│  Msg 3 (resolved on      │
│    merge, via Stage -1   │
│    of NEXT run)          │
└──────────────────────────┘
```

## Reference index

Read only what you need for the current stage:

| Stage / topic | Read |
|---|---|
| Env vars, Slack MCP load, multiplexer check | `reference/prereqs.md` |
| Sentry API URL forms + canonical resolve call | `reference/sentry-api.md` |
| Stage -1 reconcile + Stage 0 changelog scan | `reference/reconcile.md` |
| Stage A triage (cluster, fan-out, Explore briefs) | `reference/triage.md` |
| Rank/gate rules + GH dashboard writeup | `reference/ranking.md` |
| Stage B dispatch (plan file, zellij, PR label) | `reference/dispatch.md` |
| Reviewer raffle, self-nomination, author-collapse | `reference/raffle.md` |
| `#tech` message templates (1/2/3) + channel filter | `reference/slack.md` |
| Single-issue mode flow + `<ref>` resolution | `reference/single-mode.md` |

## Invocation modes

- **Full cycle** — `/sentry-fix [project1,project2]`: reconcile, changelog scan, triage, top 3, dispatch.
- **Dry run** — `/sentry-fix dry-run`: runs Stage A only, posts what *would* dispatch, skips Stage B.
- **Single issue** — `/sentry-fix single <ref>`: targeted dispatch, skips triage-the-world. See `reference/single-mode.md`.

## Re-trigger model

This skill does NOT auto-queue. After dispatching the top 3 and posting Message 1, it stops. To process the next 3 unresolved issues, the user re-runs `/sentry-fix`. Natural cadence: 3 PRs land, user triages them, next run picks the next 3.

## Out of scope

- Prod deploy gating — resolution happens on `dev` merge, not on prod. If a fix doesn't actually work in prod, Sentry will re-open the issue naturally.
- Cross-issue dedup across cycles — within a cycle we cluster (see `reference/triage.md`), but two Sentry issues in different cycles each get their own spec loop. Fine for now; revisit if noisy.
- Retry of previously-gated issues — each run re-triages fresh, so a previously-low-confidence issue may get a different verdict next run.
