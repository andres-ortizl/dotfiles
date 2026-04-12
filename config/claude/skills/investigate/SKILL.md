---
name: investigate
description: "Autonomously investigate and fix a bug from an error, stacktrace, or failing behavior. Traces the error path, forms hypotheses, writes a reproduction test, implements the fix, and commits. Triggers on: investigate this bug, fix this error, debug this stacktrace, production error, trace this error, fix this issue."
---

# Autonomous Bug Investigation

You are given a production error, stacktrace, or bug report. Fix this autonomously. Do NOT ask the user questions — make your best judgment call and document reasoning at each step.

---

## Agent Strategy

Decide between subagents and agent teams based on complexity:

**Simple bugs (1-2 files, obvious traceback):** Use subagents (Agent tool) for quick parallel reads. Use `model: "haiku"` for file reads and `model: "sonnet"` for tracing logic.

**Complex bugs (3+ files, multiple possible root causes):** Create an agent team. Teammates can communicate with each other, share a task list, and challenge each other's findings — subagents can't do this. Prompt the lead like:

```
Create an agent team to investigate this bug with 3 teammates:
- A reader teammate using Haiku to explore all files in the traceback and report data structures and function signatures
- A tracer teammate using Sonnet to follow the call chain from entry point to crash and identify where state diverges
- A hypothesis teammate using Opus to form ranked root cause hypotheses once reader and tracer report back, then design a minimal reproduction test

Have them challenge each other's findings before converging on a root cause.
```

Teams coordinate via a shared task list and direct messaging. The lead synthesizes findings. See https://code.claude.com/docs/en/agent-teams for full docs.

---

## Phase 1: Parse the Error

Extract from the error/stacktrace:
- Exception type and message
- File(s) and line numbers in the traceback
- The call chain that led to the failure
- Any relevant request/input data

Spawn **parallel haiku agents** to read all source files mentioned in the traceback simultaneously.

## Phase 2: Investigation Plan

Create a structured plan using TaskCreate with checkable items:
- Trace the error path through the codebase
- Identify root cause
- Write reproduction test
- Implement fix
- Verify with test suite
- Commit

## Phase 3: Hypotheses

After reading the code, form **2-3 hypotheses** ranked by likelihood:

1. **Most likely** — description + supporting evidence from code
2. **Possible** — description + evidence
3. **Less likely** — description + evidence

If hypotheses require exploring independent code paths, spawn **parallel sonnet agents** to investigate each one concurrently.

Document these before proceeding.

## Phase 4: Reproduce (RED)

Write a minimal failing test that:
- Reproduces the exact failure mode from the stacktrace
- Uses the project's existing test patterns, fixtures, and builders
- Follows Arrange-Act-Assert

Run it to confirm it fails as expected. Do NOT commit yet (RED phase).

## Phase 5: Fix (GREEN)

Implement the fix for the most likely hypothesis:
- Smallest possible change
- Follow existing code style (check `.claude/rules/`, `CLAUDE.md`)
- No new dependencies without explicit approval

Run the reproduction test to confirm it passes.

## Phase 6: Verify

Run the **full relevant test suite** using the project's test runner:
- If tests fail, iterate on the fix (up to 3 attempts)
- If hypothesis #1 was wrong, move to #2, then #3
- If all hypotheses fail, document findings and stop

## Phase 7: Ship

Once all tests pass:
1. Branch: `fix/<short-kebab-description>`
2. Commit with conventional format: `fix: <concise description of what was wrong>`
3. Ask the user if they want to run `/pr` to push and create a PR

## Phase 8: Summary

```
Root cause:  [what was actually wrong]
Fix:         [what changed and why]
Tests:       [which tests verify the fix]
Risks:       [potential side effects or edge cases]
Hypotheses:  [which were right/wrong and why]
```

---

## Rules

- Make your best judgment — no questions to the user
- Parallelize with subagents — don't do sequentially what can be done concurrently
- Keep changes minimal and focused
- Follow the project's existing conventions
- If you hit a dead end, try the next hypothesis before giving up
- Prefer IoC/refactoring over mocking when writing tests
