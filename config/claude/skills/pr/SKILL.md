---
name: pr
description: "Commit changes grouped by logical chunks, push to a feature branch, and create a PR. Targets 'dev' if it exists on origin (anyformat convention), otherwise the repo's default branch. Triggers on: commit, push, create PR, ship it, send PR."
triggers:
  - commit
  - push
  - create pr
  - ship it
  - send pr
---

# Chunked Commit & PR

Commit changes grouped by logical chunks of work, push to a feature branch, and create a PR.

## Base branch detection

Run this once at the start and reuse `$base` throughout:

```bash
if git ls-remote --exit-code --heads origin dev >/dev/null 2>&1; then
  base=dev
else
  base=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
fi
```

Anyformat repos use `dev`; other repos fall back to whatever `main`/`master` the remote declares as default.

## Workflow

### 1. Check branch state

```bash
current_branch=$(git branch --show-current)
```

- If on `$base` or `main` → create a new feature branch: `git checkout -b <descriptive-name>`
- If on an UNRELATED feature branch → create a new branch from `$base`: `git checkout $base && git pull && git checkout -b <descriptive-name>`
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

### 3. Hygiene pass (before committing)

If any staged or modified files are Python (`.py`, `.pyi`), invoke the `python-hygiene` skill first to run ruff autofix + format and ty type-check. Fix anything ty surfaces and re-run. Do NOT proceed to step 4 if ty or ruff still report errors after autofix — surface them to the user.

For non-Python languages, run their native quality tools (e.g. `npm run lint`, `cargo clippy`) using whatever the project already configures. No equivalent skill yet — add one if it becomes routine.

### 4. Create commits

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

### 5. Sync with base branch

Before pushing, check if the branch is behind `$base`:

```bash
git fetch origin $base
git log --oneline HEAD..origin/$base
```

If there are upstream commits, rebase:
```bash
git rebase origin/$base
```

If conflicts arise, resolve them carefully — understand what both sides intended before choosing. After resolving, continue with `git rebase --continue`.

### 6. Run tests

Use the `/run-tests` skill to run tests for affected packages. Do NOT include markers like `-m llm` or `-m slow` — only run the default test suite.

### 7. Push

```bash
git push -u origin <branch-name>
```

If the branch was rebased after a previous push, use `--force-with-lease`.

### 8. Create PR if none exists

Check for existing PR:
```bash
gh pr list --head <branch-name> --state open
```

If no PR exists, create one targeting `$base`:
```bash
gh pr create --base "$base" --title "<title>" --body "$(cat <<'EOF'
## Summary
<bullet points describing the changes>

## Changes
<one line per commit describing what changed>
EOF
)"
```

If PR already exists, skip creation and return the existing PR URL.

## Important

- Target `$base` (detected above) — in anyformat this is `dev`, elsewhere it's the repo default. Never override manually.
- Group related files into the same commit
- Each commit should pass tests independently if possible
- Return the PR URL when done
