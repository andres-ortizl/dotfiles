---
name: review-plan
description: "Review a plan before execution. Score viability, flag issues, and propose a multi-agent team structure for parallel execution. Triggers on: review plan, score plan, review my plan, is this plan good, plan review."
triggers:
  - review plan
  - score plan
  - review my plan
  - is this plan good
  - plan review
---

# Review Plan

Review a plan before execution: score it, flag issues, and propose a team of agents to execute it in parallel.

## Phase 1: Locate the Plan

Find the plan from one of these sources (in priority order):
1. The current task list (check with TaskList or read `tasks/todo.md`)
2. The most recent plan mode output in the conversation
3. Whatever the user pasted or referenced

If no plan is found, ask the user to point to one.

## Phase 2: Score

Rate each dimension 0-10 with a one-line justification:

```
## Plan Scorecard

| Dimension     | Score | Notes |
|---------------|-------|-------|
| Viability     | ?/10  | Can this be built as described? |
| Completeness  | ?/10  | Missing steps, unstated assumptions? |
| Risk          | ?/10  | What could go wrong? Edge cases? |
| Scope         | ?/10  | Right-sized or over-engineered? |

**Overall: ?/40**
```

Scoring guide:
- **8-10**: Good to go
- **5-7**: Needs revision before execution
- **0-4**: Rethink the approach

## Phase 3: Flag Issues

List concrete problems, not vague concerns:

```
## Issues

1. [BLOCKER] Step 3 assumes X exists but it was removed in PR #NNN
2. [RISK] Step 5 modifies shared config — concurrent edits will conflict
3. [SCOPE] Steps 7-9 could be a separate PR, they're not needed for the core feature
4. [MISSING] No step for running tests after the refactor
```

Severity levels:
- **BLOCKER** — must fix before starting
- **RISK** — could cause problems, plan around it
- **SCOPE** — consider removing or deferring
- **MISSING** — add a step

## Phase 4: Propose Agent Team Execution

Based on the plan, propose a team structure for parallel execution. Consider:
- Which steps are independent and can run in parallel?
- Which steps have dependencies and must be sequential?
- What's the right model for each teammate's workload?

```
## Proposed Team

**Teammates: N**

| Teammate | Model | Owns | Depends on |
|----------|-------|------|------------|
| frontend | Sonnet | Steps 1-3 (UI components) | — |
| backend | Sonnet | Steps 4-6 (API + use cases) | — |
| tests | Sonnet | Steps 7-8 (test coverage) | frontend, backend |
| reviewer | Haiku | Final review pass | all |

**Execution order:**
1. `frontend` and `backend` start in parallel
2. `tests` starts after both complete
3. `reviewer` does a final pass

**Prompt for the lead:**
> Create an agent team with 4 teammates:
> - "frontend" using Sonnet: implement steps 1-3 — [details]
> - "backend" using Sonnet: implement steps 4-6 — [details]
> - "tests" using Sonnet: write tests for steps 7-8 after frontend and backend finish — [details]
> - "reviewer" using Haiku: review all changes for consistency once tests pass
> Require plan approval before teammates make changes.
```

Always include the ready-to-paste prompt for creating the team.

## Phase 5: Present and Wait

Show the full review (scorecard + issues + team proposal) and **STOP**. Wait for the user to:
- **Approve** → proceed with the team creation prompt
- **Revise** → update the plan based on feedback, re-review
- **Simplify** → drop the team, execute sequentially
- **Reject** → scrap and rethink

## Rules

- Read the actual codebase before scoring — don't guess whether files/functions exist
- If the plan is small (1-3 steps, single package), skip the team proposal and say "this doesn't need a team — just execute sequentially"
- Use Haiku for read-only teammates (reviewers, explorers). Use Sonnet for implementation. Use Opus only for complex architectural decisions.
- Each teammate should own different files — flag conflicts in the issues section
- The team prompt must include enough context for each teammate since they don't inherit conversation history
