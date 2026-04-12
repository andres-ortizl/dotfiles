---
name: chunked-build
description: "Implement a plan in logical, ordered sequential chunks. Each chunk is proposed with current/after blocks for approval before applying."
triggers:
  - chunked build
  - build in chunks
  - implement in chunks
  - chunk by chunk
---

# Chunked Build

Implement a plan incrementally — one logical chunk at a time, with user approval before each change.

## Workflow

### 1. Present the plan

Break the work into ordered chunks. Each chunk is one logical change. Include tests as chunks but group them at the end.

```
### Plan

Chunk 1 (`worker.py`) — scope table context to assigned tables only
Chunk 2 (`worker.py`, `transformer.py`) — extract shared briefing into ExtractionContext
Chunk 3 (`prompts.py`) — remove duplicate workflow section from worker prompt
Chunk 4 (`tests/test_worker.py`, `tests/test_transformer.py`) — tests for chunks 1-3
```

Rules:
- List affected file(s) in backticks
- One-line description, not verbose
- Order by dependency — if chunk 3 depends on chunk 1, chunk 1 comes first
- Group test chunks at the end, referencing which implementation chunks they cover

Wait for plan approval before starting.

### 2. Propose each chunk

For each chunk, show `#current` / `#after` blocks per affected file:

```
### Chunk 1/N: <description>

**Files:** `worker.py`

**#current**
\```python
<exact code as it exists today>
\```

**#after**
\```python
<proposed replacement>
\```

Apply, skip, or modify?
```

Rules:
- Show enough surrounding context (5-15 lines)
- If a chunk touches multiple files, show each file's `#current` / `#after` separately
- One logical change per chunk — don't bundle unrelated work

### 3. Wait for response

**STOP and wait.** Do NOT proceed until the user responds:
- **Apply** / "yes" / "lgtm" → apply the change, propose the next chunk
- **Skip** / "no" → skip it, propose the next chunk
- **Modify** → user gives feedback, re-propose with revisions, wait again
- **Stop** → stop the build

### 4. After all chunks

Run tests using the `/run-tests` skill. Show summary:

```
Applied: #1, #2, #4
Skipped: #3 (user: "not needed")
Modified: #2 (adjusted per feedback)
Tests: ✓ all passing
```

## Important

- If a chunk depends on an earlier one, note it: "**Depends on:** #1"
- If the user says "apply all remaining" — apply everything left without further review
