---
name: tagged-review
description: Review all `# AIREVIEW:` tagged comments in a file or set of files. Produces a structured verdict table and execution plan grouped by priority.
triggers:
  - tagged review
  - aireview
  - review aireview
  - process aireview
  - review tags
  - aireview comments
---

# Tagged Review: Structured Code Review

Process `# AIREVIEW:` tagged comments left by the developer in source files. These are review prompts — questions, suggestions, or concerns — that need a structured response.

---

## Phase 1: Collect

Find all AIREVIEW comments in the target file(s):

```bash
grep -n "AIREVIEW:" <file_or_directory>
```

If the user specified a file, search only that file. If they pointed at a directory or said "all", search recursively.

For each comment, extract:
- **Line number**
- **The full comment text** (after `AIREVIEW:`)
- **Surrounding code context** (read 5 lines above and below to understand what the comment refers to)

---

## Phase 2: Review

For EVERY comment, produce a verdict. No skipping.

Read the relevant code around each comment. Understand what the code does and what the comment is asking. Then decide:

| Verdict | Meaning |
|---------|---------|
| **Agree** | The comment is right. The code should change. |
| **Partially agree** | The concern is valid but the proposed fix is wrong or incomplete. |
| **Deny** | The code is correct as-is. Explain why. |
| **Defer** | Valid concern but out of scope for this session. Track as follow-up. |

For each comment, write a **proposal** — what specifically should be done (even if the proposal is "remove the comment, no change needed").

---

## Phase 3: Present

Present results as a numbered table in execution order (following the code's runtime flow, not line number order). Group by the function/section they belong to.

Format:

```
### <Function/Section Name> (L<start>-L<end>)

| # | Line | Comment | Verdict | Proposal |
|---|------|---------|---------|----------|
| 1 | 42 | <comment text> | Agree | <what to do> |
| 2 | 58 | <comment text> | Deny | <why it's fine> |
```

After the table, provide a **Summary** section grouping ALL items by action timing — include every item, not just "do now":

```
## Summary

**Do now (this session):**
- #1: <one-line description>
- #3: <one-line description>

**Do next (follow-up PR):**
- #5: <one-line description>

**Defer (separate feature work):**
- #7: <one-line description>

**Deny (no change):**
- #2: <reason>
```

---

## Phase 4: Execute via chunked-review

Do NOT start fixing anything until the user approves the plan. Wait for explicit confirmation.

Once the user approves, invoke the `chunked-review` skill to apply changes one at a time. Include ALL items from the summary (not just "do now") — the user may want to tackle everything.

Each chunk in the chunked-review should include:
- The specific AIREVIEW comment(s) being addressed
- Why the change is needed (the context from Phase 2)
- `#current` / `#proposal` blocks

**Important interactions learned from practice:**
- When a chunk involves refactoring (e.g., package split), update ALL consumers (imports in tests, graph nodes, etc.) as part of the same chunk — don't leave shims or redirect files.
- When a chunk touches a type or constant used in multiple places, show all affected locations in the proposal.
- The user may modify proposals during chunked-review — adapt and re-present.
- If a "deny" item gets challenged, re-evaluate honestly rather than defending the original verdict.

After all chunks are applied:
1. Run tests to verify nothing broke
2. Verify zero `# AIREVIEW:` tags remain (grep the affected files)
3. Present a final summary of what was applied, skipped, and modified

---

## Rules

- **Review EVERY tagged comment** — no silent skips
- **Execution order matters** — present in the order code runs, not line order. This helps the user understand the flow.
- **Be opinionated** — don't agree with everything. Push back on over-engineering, premature abstractions, and changes that add complexity without clear benefit.
- **Proposals must be specific** — "refactor this" is not a proposal. "Extract lines 42-58 into a `_group_by_rule()` function" is.
- **Deny is a valid verdict** — code doesn't need to change just because someone left a comment. Explain why it's fine.
- **Defer is not a wastebasket** — only defer if the change is genuinely out of scope (different feature, different PR, needs design discussion). Don't defer things that are quick to fix.
- **Remove ALL tags when done** — AIREVIEW comments are ephemeral review markers, not permanent documentation. Every `# AIREVIEW:` comment MUST be removed after processing, regardless of verdict (agree, deny, or defer). A file with zero `# AIREVIEW:` tags is the only acceptable end state. Grep the file after execution to verify none remain.
- **Update all consumers** — when refactoring (renames, moves, package splits), update every file that imports the changed code. Never leave redirect shims as a permanent solution.
- **Frontend + backend together** — when a review item needs changes on both sides (e.g., validation), propose both in the same chunk so nothing is half-done.
