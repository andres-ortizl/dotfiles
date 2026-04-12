---
name: pr
description: "Commit changes grouped by logical chunks, push to a feature branch, and create a PR targeting dev. Triggers on: commit, push, create PR, ship it, send PR."
triggers:
  - commit
  - push
  - create pr
  - ship it
  - send pr
---

# Chunked Commit & PR

Commit changes grouped by logical chunks of work, push to a feature branch, and create a PR targeting `dev`.

## Workflow

### 1. Check branch state

```bash
current_branch=$(git branch --show-current)
```

- If on `main` or `dev` → create a new feature branch: `git checkout -b <descriptive-name>`
- If on an UNRELATED feature branch → create a new branch from `dev`: `git checkout dev && git pull && git checkout -b <descriptive-name>`
- If on the correct feature branch → stay on it

Branch naming: `<type>/<short-description>` (e.g. `fix/smart-table-worker-scoping`, `refactor/smart-table-prompts`)

### 2. Group changes into logical commits

Review all changed files with `git diff` and `git status`. Group them into logical chunks — each commit should represent one coherent change.

**Commit message format:** `<type>(<scope>): <description>`

Types: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`

Example grouping for a multi-chunk refactor:
```
Commit 1: refactor(smart-table): scope worker context to assigned tables
Commit 2: refactor(smart-table): consolidate briefing into ExtractionContext
Commit 3: refactor(smart-table): remove duplicate workflow from worker prompt
```

### 3. Create commits

For each logical group:
```bash
git add <files-for-this-chunk>
git commit -m "<type>(<scope>): <description>"
```

**Rules:**
- Do NOT use `--no-verify` or skip hooks
- Do NOT amend commits that have been pushed
- Do NOT commit `.env`, credentials, or secrets
- Do NOT add `Co-Authored-By` trailers
- Keep commits atomic — one logical change per commit
- **Dependency changes:** use `uv add` / `uv remove` instead of hand-editing `pyproject.toml` — this keeps `uv.lock` in sync automatically

### 4. Sync with base branch

Before pushing, check if the branch is behind `dev`:

```bash
git fetch origin dev
git log --oneline HEAD..origin/dev
```

If there are upstream commits, rebase:
```bash
git rebase origin/dev
```

If conflicts arise, resolve them carefully — understand what both sides intended before choosing. After resolving, continue with `git rebase --continue`.

### 5. Run tests

Use the `/run-tests` skill to run tests for affected packages. Do NOT include markers like `-m llm` or `-m slow` — only run the default test suite.

### 6. Push

```bash
git push -u origin <branch-name>
```

If the branch was rebased after a previous push, use `--force-with-lease`.

### 7. Create PR if none exists

Check for existing PR:
```bash
gh pr list --head <branch-name> --state open
```

If no PR exists, create one. **Always target `dev`** — never create PRs against `main`:
```bash
gh pr create --base dev --title "<title>" --body "$(cat <<'EOF'
## Summary
<bullet points describing the changes>

## Changes
<one line per commit describing what changed>
EOF
)"
```

If PR already exists, skip creation and return the existing PR URL.

## Important

- **Always target `dev`** — never PR against `main`
- Group related files into the same commit
- Each commit should pass tests independently if possible
- Return the PR URL when done
