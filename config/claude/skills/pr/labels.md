# PR Labels — Reuse Only

Apply labels to the PR based on the diff and the commit-type prefix. **Never create a new label** — if a candidate isn't already in `gh label list`, drop it silently.

## Hard exclusions (read this first)

**Never apply `claude-code-assisted`, `claude-assisted`, or any other AI/agent attribution tag.** They exist in the catalogue but the user does not want them on their PRs — everyone already knows the user works with AI, the tag is noise. This applies to every PR, every time, no exceptions. If you're tempted to add it because "the PR was written with AI," that is *exactly* when not to. The rule is permanent, not conditional.

If you find yourself building the `--add-label` CSV and one of those labels is in the candidate set, **drop it before running the command** — not after, not in a follow-up edit.

## Step 1 — Fetch the label catalogue

```bash
existing_labels=$(gh label list --limit 100 --json name --jq '.[].name')
```

Match candidates against this list; ignore any that don't appear.

## Step 2 — Derive candidates

Run `git diff --name-only origin/$base...HEAD` and compute candidates from the file list + the commit-type prefix of the first commit.

### Path → label

| Path pattern | Label |
|---|---|
| `anyformat/services/frontend/**` or `**/*.tsx`, `**/*.ts` (frontend), `**/*.jsx`, `**/*.js` | `FE`, `javascript` |
| `anyformat/services/backend/**` or `**/*.py` | `Backend`, `python` |
| `.github/workflows/**`, `.github/actions/**` | `github_actions` |
| Only `*.md` / `docs/**` changes | `documentation` |
| `**/migrations/**` (new file) | (no label, but **flag in PR body's Why section**) |

A PR can match multiple rows — apply all that fit.

### Commit type → label

Look at the prefix of the first commit message (`fix(...)`, `feat(...)`, etc.):

| Commit type | Label |
|---|---|
| `fix` | `bug` |
| `feat` | `Feature` |
| `refactor` | `Improvement` |
| `chore`, `docs`, `test`, `ci` | (no type-based label) |

## Step 3 — Skip list

Never apply labels in this list — they're owned by automation or human PMs:

- `in-progress`, `ready-to-work`, `needs-review`, `needs-work`, `needs-human-review`, `needs-human-help`, `human-approve-merge`, `budget-exhausted`
- `phase-0` through `phase-7`
- `v3-bet-automation`, `sentry-triage`, `sentry`
- `dependencies`, `python:uv` (dependabot territory)
- (AI-attribution tags — covered in "Hard exclusions" at the top of this file.)

## Step 4 — Apply

```bash
gh pr edit "$pr_number" --add-label "$label1,$label2,..."
```

If the PR already had labels (e.g. on re-runs), `--add-label` is additive and idempotent — safe to re-apply.

## Rule of thumb

If you're unsure whether a label fits, **don't apply it**. The cost of a missing label is low; the cost of polluting the label set is high.
