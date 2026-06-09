# Linear Ticket Linkage

PRs that reference a Linear ticket get auto-linked: Linear moves the issue to "In Review" on push and "Done" on merge. This is the only reliable way to track work without manual Linear hygiene.

The magic phrase Linear looks for in the PR body: **`Closes ANY-NNN`** (also `Fixes`, `Resolves`). Place it at the very top of the body.

**Default team: `Anyformat`.** Use it for both searches and ticket creation without asking. Only deviate to `Operations` (or another team) when the diff scope obviously belongs there — never list teams to the user.

**Default project for chore / infra / tech-debt / dev-tooling PRs: `Platform Health`.** Its charter literally is "dedicated capacity for unplanned work, address technical debt incrementally." Use it when no clearer feature project (e.g. `Day One Ready`, `Parse Level-Up`, `API Devex`, `Billing 2.0`, etc.) fits the diff. Pick a feature project over `Platform Health` only when the diff is clearly part of that feature's roadmap.

## Workflow

### 1. Load the Linear MCP tools

The Linear tools are deferred — fetch them before calling:

```
ToolSearch(query: "select:mcp__linear-server__list_issues,mcp__linear-server__save_issue,mcp__linear-server__get_issue", max_results: 5)
```

If `mcp__linear-server__` tools aren't available at all (no MCP server configured), skip the Linear step entirely and warn the user once.

### 2. Check the branch name first

If the branch name matches `ANY-\d+` (e.g. `fix/ANY-1234-foo`), use that ticket directly — no search needed. Drop into step 5.

### 3. Search Linear for related tickets

Build a query from the first commit message (strip the `<type>(<scope>):` prefix) and the branch name. Search the team's active issues:

```
mcp__linear-server__list_issues(query: "<keywords from commit subject>", limit: 5)
```

Filter to issues in states: `Backlog`, `Todo`, `In Progress`. Skip `Done`, `Cancelled`.

### 4. Present hits to the user

Show the top 3 results as a numbered list with ID, title, and state. Add three meta-options:

```
1. ANY-1234 — Smart table worker scoping (In Progress)
2. ANY-1198 — Refactor extraction context (Todo)
3. ANY-0987 — Worker prompt cleanup (Backlog)
c.  Create a new ticket from this PR
s.  Skip — no Linear ticket
```

Use `AskUserQuestion` for the choice. Default to `s` if the user explicitly said "no ticket" earlier in the session.

### 5. Wire the chosen ticket into the PR body

Prepend to the PR body **before** `## Summary`:

```
Closes ANY-NNN

## Summary
...
```

For multiple tickets, one line each:

```
Closes ANY-1234
Closes ANY-1198
```

### 6. If user chose "Create a new ticket"

Use `mcp__linear-server__save_issue` with (no `id` parameter — that's reserved for updates):
- `title`: the PR title (strip the commit-type prefix)
- `description`: the PR `Why` paragraph
- `team`: **default to `Anyformat`** without asking. Only ask if the work clearly belongs elsewhere (e.g. `Operations`) — recognisable from the diff scope, not from keywords. Do not list teams to the user; just file it.
- `project`: **default to `Platform Health`** for chore/infra/tech-debt/dev-tooling PRs. For feature work, pick the feature project that obviously owns the diff (look at recent active projects via `mcp__linear-server__list_projects(team: "Anyformat")`). Do not list projects to the user; just file it.
- `assignee`: `me`.
- `state`: `In Review` — the PR exists, ready for human review. (Don't use `In Progress` — that suggests the work is still being written.)

Take the returned `identifier` (e.g. `ANY-1500`) and proceed to step 5.

### 7. If user chose "Skip"

Do not add any `Closes` line. The PR is created without a Linear link.

Don't nag — the user knows. But if `feat`/`fix` commits are being skipped frequently in a session, mention once that the Linear integration is the cheapest way to keep tracking.

## Edge cases

- **PR already has a `Closes ANY-NNN` line** (re-runs of the skill on an existing branch): skip the Linear step entirely; don't double-add.
- **Linear MCP returns auth errors**: surface the error to the user, ask them to run `mcp__linear-server__authenticate`, then continue without the Linear link for this run.
- **Multiple commits, mixed types**: search Linear once using the first commit's subject; the user picks one ticket to represent the whole PR.
