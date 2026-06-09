---
name: pr
description: "Commit changes grouped by logical chunks, push to a feature branch, link a Linear ticket, and create a labelled PR. Targets 'dev' if it exists on origin (anyformat convention), otherwise the repo's default branch. Triggers on: commit, push, create PR, ship it, send PR."
triggers:
  - commit
  - push
  - create pr
  - ship it
  - send pr
---

# Chunked Commit & PR

Commit changes grouped by logical chunks of work, push to a feature branch, attach a Linear ticket, label the PR, and open it.

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

Branch naming: `<type>/<short-description>` (e.g. `fix/smart-table-worker-scoping`, `refactor/smart-table-prompts`). If a Linear ticket is already known, prefer `<type>/ANY-NNN-<short-description>`.

### 2. Find or attach a Linear ticket

See [linear.md](linear.md) for the full workflow. Summary:

1. If the branch name already contains `ANY-NNN`, use it directly.
2. Otherwise, search Linear for related active issues from the first commit subject.
3. Ask the user to pick a hit, create a new ticket, or skip.
4. Remember the chosen `ANY-NNN` (or `none`) for step 9's PR body.

Do this **before** drafting commits so the body can reference the ticket.

### 3. Group changes into logical commits

Review all changed files with `git diff` and `git status`. Group them into logical chunks — each commit should represent one coherent change.

**Commit message format:** `<type>(<scope>): <description>`

Types: `fix`, `feat`, `refactor`, `docs`, `test`, `chore`, `ci`

Example grouping for a multi-chunk refactor:
```
Commit 1: refactor(smart-table): scope worker context to assigned tables
Commit 2: refactor(smart-table): consolidate briefing into ExtractionContext
Commit 3: refactor(smart-table): remove duplicate workflow from worker prompt
```

### 4. Hygiene pass (before committing)

If any staged or modified files are Python (`.py`, `.pyi`), invoke the `python-hygiene` skill first to run ruff autofix + format and ty type-check. Fix anything ty surfaces and re-run. Do NOT proceed to step 5 if ty or ruff still report errors after autofix — surface them to the user.

For non-Python languages, run their native quality tools (e.g. `npm run lint`, `cargo clippy`) using whatever the project already configures.

### 5. Create commits

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

### 6. Sync with base branch

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

### 7. Run tests

Use the `/run-tests` skill to run tests for affected packages. Do NOT include markers like `-m llm` or `-m slow` — only run the default test suite.

### 8. Push

```bash
git push -u origin <branch-name>
```

If the branch was rebased after a previous push, use `--force-with-lease`.

### 9. Create PR if none exists

Check for existing PR:
```bash
gh pr list --head <branch-name> --state open
```

If no PR exists, create one targeting `$base`. **Body template:**

```
Closes ANY-NNN                        <-- only if step 2 found/created a ticket; one line per ticket

## Summary
<2-4 bullet points: what changed, in user-visible terms>

## Why
<one short paragraph: the motivation. The single sentence a reviewer needs to decide if this is the right fix.>

## Changes
<one line per commit, describing what changed>
```

Drop `## Why` only if it would literally repeat the Summary (rare — usually they answer different questions). Drop the `Closes` line only if no ticket was attached.

```bash
gh pr create --base "$base" --title "<title>" --body "$(cat <<'EOF'
...body from template above...
EOF
)"
```

If a PR already exists, skip creation and capture the existing PR number for step 10.

### 10. Label the PR

See [labels.md](labels.md) for the full mapping. Summary:

1. Run `gh label list --limit 100 --json name --jq '.[].name'` to get the catalogue.
2. Derive candidates from changed paths and the first commit's type prefix.
3. Filter against the skip list (automation-owned labels).
4. `gh pr edit <num> --add-label "<csv>"` — only labels that exist in the catalogue.

**Never create a new label.** If a candidate isn't in the catalogue, drop it.

**Never apply `claude-code-assisted`, `claude-assisted`, or any AI-attribution tag** — they exist in the catalogue but the user does not want them. The full rationale is in `labels.md` under "Hard exclusions" at the top of that file.

## Important

- Target `$base` (detected above) — in anyformat this is `dev`, elsewhere it's the repo default. Never override manually.
- Group related files into the same commit
- Each commit should pass tests independently if possible
- Return the PR URL and the Linear ticket URL (if any) when done
