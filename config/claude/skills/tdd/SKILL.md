---
name: tdd
description: Test-driven development with red-green-refactor loop, vertical slicing, and integration-first testing. Use when building features or fixing bugs test-first, when user mentions "TDD", "red-green-refactor", "test-first", or when /spec or /chunked-review delegates the test-writing step here.
---

# Test-Driven Development

## Philosophy

**Core principle**: Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't.

**Good tests** are integration-style: they exercise real code paths through public APIs. They describe _what_ the system does, not _how_ it does it. A good test reads like a specification — `test_user_can_checkout_with_valid_cart` tells you exactly what capability exists. These tests survive refactors because they don't care about internal structure.

**Bad tests** are coupled to implementation. They mock internal collaborators, test private methods, or verify through external means (querying the DB directly instead of using the interface). The warning sign: the test breaks when you refactor, but behavior hasn't changed. If renaming an internal function fails tests, those tests were testing implementation, not behavior.

## Anti-pattern: horizontal slices

**DO NOT write all tests first, then all implementation.** This is "horizontal slicing" — treating RED as "write all tests" and GREEN as "write all code."

This produces **crap tests**:

- Tests written in bulk test _imagined_ behavior, not _actual_ behavior.
- You end up testing the _shape_ of things (data structures, function signatures) rather than user-facing behavior.
- Tests become insensitive to real changes — they pass when behavior breaks, fail when behavior is fine.
- You outrun your headlights, committing to test structure before understanding the implementation.

**Correct approach**: vertical slices via tracer bullets. One test → one implementation → repeat. Each test responds to what you learned from the previous cycle. Because you just wrote the code, you know exactly what behavior matters and how to verify it.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED → GREEN: test1 → impl1
  RED → GREEN: test2 → impl2
  RED → GREEN: test3 → impl3
  ...
```

## Workflow

### 1. Plan

Before writing any code:

- [ ] Confirm with user what interface changes are needed.
- [ ] Confirm which behaviors to test (prioritize critical paths and complex logic — you can't test everything).
- [ ] Identify opportunities for **deep modules** (small interface, deep implementation). See `/improve-codebase-architecture` for the vocabulary.
- [ ] List the behaviors to test (not implementation steps).
- [ ] Get user approval on the plan.

Ask: "What should the public interface look like? Which behaviors are most important to test?"

### 2. Tracer bullet

Write ONE test that confirms ONE thing about the system:

```
RED:   write test for first behavior → test fails
GREEN: write minimal code to pass → test passes
```

This is your tracer bullet — proves the path works end-to-end.

### 3. Incremental loop

For each remaining behavior:

```
RED:   write next test → fails
GREEN: minimal code to pass → passes
```

Rules:

- One test at a time.
- Only enough code to pass the current test.
- Don't anticipate future tests.
- Keep tests focused on observable behavior.

### 4. Refactor

After all tests pass, look for refactor candidates:

- [ ] Extract duplication.
- [ ] Deepen modules (move complexity behind simple interfaces).
- [ ] Apply SOLID principles where natural.
- [ ] Consider what new code reveals about existing code.
- [ ] Run tests after each refactor step.

**Never refactor while RED.** Get to GREEN first.

## Per-cycle checklist

```
[ ] Test describes behavior, not implementation
[ ] Test uses public interface only
[ ] Test would survive an internal refactor
[ ] Code is minimal for this test
[ ] No speculative features added
```

## Python-stack specifics

Default stack across our repos: **pytest** for tests, **ruff** for lint/format, **ty** (Astral) for type checking. Patterns and gotchas below assume that stack.

### Mocking discipline

- **Avoid mocks for code you own.** If your test requires patching an internal function, it's a sign the seam is wrong — refactor instead.
- **Mock at the boundary, not inside it.** Mock the HTTP client, the DB driver, the file system — never the business-logic function the test is supposed to exercise.
- `monkeypatch` is fine for env vars, time, and external SDK clients. `unittest.mock.patch` for substituting integration adapters at the seam.
- **Prefer fakes over mocks** when behavior matters: an in-memory repository that satisfies the same interface beats a `Mock(spec=...)` whose return values you have to script line by line.
- For LLM/agent code: if the test is meaningless without a real LLM call, write a small evaluation script instead of a mock-heavy unit test.

### Integration first

In our repos, prefer:

1. Integration tests that hit a real (containerised) Postgres / Redis / S3 stub.
2. Service-level tests that exercise the FastAPI/LangGraph/etc. layer end-to-end with deps wired up.
3. Pure-function unit tests for genuinely complex pure logic (parsers, scoring, etc.).
4. Mocked-collaborator unit tests **only** when integration is impractical and the logic is gnarly enough to need its own test.

Run `pytest -x -ra` while iterating; full suite at the end.

### Vertical slice in a Python repo

A single tracer-bullet slice typically touches:

- One pytest function exercising the new behavior end-to-end.
- One change to the public function/route/handler that fails the test.
- The minimal implementation under that.
- `ruff check --fix` + `ty check` clean before committing.

If a slice touches more than ~3 files of new logic, it's not vertical — split it.

## When this skill is invoked from another skill

- `/spec` Phase 2 — when the lead delegates implementation to the coder, the coder follows this skill's RED → GREEN cadence rather than batching tests.
- `/chunked-review` (a.k.a. `/chunked-build`) — each chunk is one tracer-bullet slice; this skill is the discipline for what "one chunk" looks like.
- `/diagnose` Phase 5 — regression tests for fixed bugs follow this skill's "behavior, not implementation" rule and live at the seam where the bug actually occurs.
