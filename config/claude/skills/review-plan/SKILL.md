---
name: review-plan
description: "Companion to a plan. Runs AFTER a plan exists (from plan mode, /spec Phase 1, or a plan.md file) and appends: viability + scoring + concerns + agent-team execution strategy. Use when you want a second-opinion pass before execution. Do NOT use to generate a plan from scratch — assumes a plan already exists."
triggers:
  - review plan
  - score this plan
  - plan review
---

# Review Plan

Second-opinion pass on an existing plan: score it, flag concrete concerns, propose an agent-team execution strategy. Output is additive — it doesn't change the plan.

## Phase 1: Locate the plan

Input in priority order:

1. Explicit path argument (`/review-plan ~/.spec/<project>/<spec>/plan.md`)
2. Most recent plan-mode output in the current conversation

If neither is available, ask the user for a path. Do NOT invent a plan.

## Phase 2: Small-plan short-circuit

If the plan is ≤3 steps OR touches a single file/module, **skip the team proposal entirely** and output:

> This plan is small enough to execute sequentially. Skipping the team proposal. See scorecard and concerns below.

Still run the scorecard and concerns — they're valuable regardless of size.

## Phase 3: Scorecard

Rate each dimension 0–10 with a one-line justification:

```
## Scorecard

| Dimension              | Score | Notes |
|------------------------|-------|-------|
| Viability              | ?/10  | Can this be built as described given the current codebase? |
| Completeness           | ?/10  | Missing steps, unstated assumptions? |
| Acceptance criteria    | ?/10  | Concrete, testable, includes at least one edge case? |
| Risk                   | ?/10  | What could go wrong? Edge cases? |
| Scope discipline       | ?/10  | Right-sized or over-engineered? |

**Verdict: Go | Revise | Rethink**
```

Verdict thresholds (all-in, not an average — a BLOCKER in any dimension dominates):

- **Go** — no BLOCKERs, Viability ≥7, AC ≥6
- **Revise** — BLOCKER(s) present but fixable, or any dimension ≤5
- **Rethink** — Viability ≤4, or the plan solves the wrong problem

Read the actual codebase before scoring. Don't guess whether files/functions exist.

## Phase 4: Concerns

Concrete problems only — no vague worries:

```
## Concerns

1. [BLOCKER] Step 3 assumes `FooService.bar()` exists but it was removed in PR #NNN
2. [RISK] Step 5 modifies shared config — concurrent edits with <other workstream> will conflict
3. [SCOPE] Steps 7-9 belong in a separate PR — not needed for the core feature
4. [MISSING] No step for running tests after the refactor
5. [AC] Acceptance criterion 2 is untestable ("works correctly") — rewrite as specific behavior
```

Severity:

- **BLOCKER** — must fix before starting; verdict cannot be Go while unresolved
- **RISK** — could cause problems, plan around it
- **SCOPE** — consider removing or deferring
- **MISSING** — add a step
- **AC** — acceptance criterion needs sharpening

## Phase 5: Agent-team execution strategy

(Skipped if Phase 2 short-circuited.)

### Dependency graph

Show which steps run in parallel and which are sequential:

```
[frontend steps 1-3] ─┐
                      ├→ [tests steps 7-8] → [reviewer]
[backend steps 4-6]  ─┘
```

Steps on the same row run in parallel. Arrows mean "blocks on".

### Team table

```
| Teammate | Model  | Owns             | Touches                          | Depends on       |
|----------|--------|------------------|----------------------------------|------------------|
| frontend | Sonnet | Steps 1-3 (UI)   | src/components/, src/hooks/      | —                |
| backend  | Sonnet | Steps 4-6 (API)  | src/api/, src/services/          | —                |
| tests    | Sonnet | Steps 7-8 (QA)   | tests/                           | frontend, backend|
| reviewer | Haiku  | Final pass       | (read-only)                      | all              |
```

### Conflict check

Scan the `Touches` column for overlap. Any two teammates touching the same file/module → raise as a **BLOCKER** in the Concerns section and restructure before starting:

```
⚠ frontend and backend both touch src/app/layout.tsx — serialize these or move ownership.
```

If no overlaps: `✓ No file-level conflicts between teammates.`

### Ready-to-paste lead prompt

```
Create an agent team with N teammates:
- "frontend" using Sonnet: implement steps 1-3 — <details>
- "backend" using Sonnet: implement steps 4-6 — <details>
- "tests" using Sonnet: write tests for steps 7-8 after frontend and backend finish — <details>
- "reviewer" using Haiku: review all changes for consistency once tests pass
Require plan approval before teammates make changes.
```

## Phase 6: Present and wait

Print the full review (scorecard + concerns + team strategy) and STOP. Wait for the user to:

- **Approve** → proceed with the team creation prompt
- **Revise** → update the plan based on feedback, re-review
- **Simplify** → drop the team, execute sequentially
- **Reject** → scrap and rethink

## Rules

- Read the codebase before scoring. An unverified claim is worse than no claim.
- Haiku for read-only teammates (reviewers, explorers). Sonnet for implementation. Opus only for complex architectural decisions.
- Each teammate owns different files. Conflicts escalate to BLOCKER.
- The team prompt must include enough context for each teammate since they don't inherit conversation history.
- This skill does NOT modify the plan. It produces a review document. The user decides what to change.
