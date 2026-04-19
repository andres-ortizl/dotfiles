---
name: spec
description: "End-to-end feature development loop. You describe a feature, iterate on the plan, then the team implements, reviews, creates PR, and handles Greptile feedback autonomously. DMs you at milestones."
triggers:
  - spec
  - build feature
  - develop
  - end to end
---

# Spec: End-to-End Feature Development

You are the lead/coordinator of a development team. You plan with the user, then create a team of agents (coder, reviewer) to drive a feature from approved plan to merged PR.

## The Loop

```
User describes feature
        │
        ▼
┌─ SETUP ──────────────────┐
│  Create .spec/<name>/     │
│  Enter worktree            │
│  Copy .spec-env → .env    │
│  Set ports + project name  │
└───────┬────────────────────┘
        ▼
┌─ PLAN (interactive) ─────┐
│  Lead enters plan mode     │
│  User iterates directly    │
│  with lead until approved  │
└───────┬────────────────────┘
        │ plan approved
        ▼
┌─ IMPLEMENT (autonomous) ─┐
│  Coder implements plan    │
│  TDD: RED → GREEN         │
│  Parallelizes independent │
│  chunks via sub-agents    │
│  STAYS ALIVE for feedback │
└───────┬───────────────────┘
        │ reports done
        ▼
┌─ REVIEW (autonomous) ────┐
│  Reviewer checks code     │
│  PASS → continue          │
│  FAIL → send findings to  │
│  coder via SendMessage    │
│  Loop until PASS (max 3)  │
└───────┬───────────────────┘
        │ PASS
        ▼
┌─ SHIP (autonomous) ──────┐
│  /pr skill: commit, push, │
│  create PR                │
└───────┬───────────────────┘
        │ PR created
        ▼
┌─ CI WATCH (autonomous) ──┐
│  Poll pipeline checks     │
│  Easy fix → commit + push │
│  Hard fix → DM user + stop│
│  Loop until all green     │
└───────┬───────────────────┘
        │ CI green
        ▼
┌─ GREPTILE (autonomous) ──┐
│  Wait for Greptile review │
│  /react-to-greptile skill │
│  DM user every round      │
│  Loop until score ≥ 5/5   │
└───────┬───────────────────┘
        │ done
        ▼
      COMPLETE
```

## Phase 0: Setup

### 0. Session persistence check

Check if running inside a terminal multiplexer:

```bash
# Zellij
test -n "$ZELLIJ_SESSION_NAME"
# tmux
test -n "$TMUX"
```

If **neither** is set, warn the user before proceeding:

> You're not inside Zellij or tmux. If you close this terminal, the autonomous loop will die. Recommended: start a Zellij session first:
> ```
> zellij attach spec-<spec-name>
> ```
> Then run `/spec` again inside it. After plan approval, detach with `Ctrl+O, D` — the loop keeps running and you'll get Slack DMs at each milestone.

Wait for the user to confirm they want to continue anyway, or exit and restart in Zellij.

### 0b. Discover Slack user ID and verify permissions

Get the current user's Slack ID from the MCP tool description (it includes the logged-in user's user_id). Store it as `<slack-user-id>` for all DMs in this spec.

Then send the "Spec started" DM silently — do NOT ask the user before sending, just send it:

```
mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message=":rocket: *[<spec name>]* Spec started — setting up workspace")
```

If the tool triggers a permission prompt (this is the system asking, not you), the user needs to select **"Yes, and don't ask again"**. Only then mention it:

> Select "Yes, and don't ask again" so the autonomous loop can send DMs without blocking.

If the DM goes through without a prompt, say nothing about it — just continue.

### 1. Derive spec name and project name

- `<spec-name>`: convert the feature description to a short kebab-case slug (e.g., "auth-middleware", "snake-game")
- `<project-name>`: the basename of the current project directory (e.g., "anyformat-backend", "spec-dashboard")

These are used everywhere.

### 2. Create spec directory

All specs live in a centralized location: `~/.spec/<project-name>/<spec-name>/`. This is the single registry of all specs across all projects.

```bash
mkdir -p ~/.spec/<project-name>/<spec-name>
```

This directory holds:

- **`plan.md`** — the approved plan
- **`logbook.md`** — timeline of the development process
- **`env.md`** — record of ports and project name assigned

If `~/.spec/<project-name>/<spec-name>/` already exists, append a numeric suffix: `<spec-name>-2`, `<spec-name>-3`, etc.

### 3. Enter worktree (if needed)

Check if the current working directory is already a worktree:

```bash
git rev-parse --is-inside-work-tree && git worktree list
```

If already in a worktree (e.g., created by Conductor or another tool), **skip worktree creation** — just use the current directory. Log which worktree/branch is being used.

If on the main working tree, create an isolated worktree:

```
EnterWorktree(name="spec/<spec-name>")
```

This creates a new branch and working directory at `.claude/worktrees/spec/<spec-name>`. All implementation happens here — the main working tree is untouched.

### 4. Copy environment

Check for `.spec-env` in the project root. If it exists, copy it silently into the worktree as `.env`. If it doesn't exist, warn once and continue — do NOT block:

> No `.spec-env` found in project root. The worktree won't have any env vars. Create one at the project root if needed.

```bash
cp <original-project-root>/.spec-env .env 2>/dev/null
```

### 5. Assign ports and project name

Find the lowest available port offset by checking which offsets are in use by active specs across ALL projects:

1. Read every `~/.spec/*/*/logbook.md` — if status is NOT `COMPLETE`, that spec is active
2. Read every active spec's `env.md` to find its offset (derive from any port, e.g., `BACKEND_PORT - 8080`)
3. Pick the lowest multiple of 10 (starting at 10) not used by any active spec

Offset 0 is reserved for the user's own dev stack (default ports).

```
offset = lowest unused multiple of 10, starting at 10
```

Append to the worktree's `.env`:

```env
COMPOSE_PROJECT_NAME=spec-<spec-name>
FRONTEND_PORT=$((5173 + offset))
BACKEND_PORT=$((8080 + offset))
API_PORT=$((8081 + offset))
POSTGRES_PORT=$((5432 + offset))
```

Log the assigned ports in `~/.spec/<project-name>/<spec-name>/env.md`:

```markdown
# Environment: <spec-name>

Worktree: .claude/worktrees/spec/<spec-name>
Branch: spec/<spec-name>
COMPOSE_PROJECT_NAME: spec-<spec-name>

| Service   | Port  |
|-----------|-------|
| Frontend  | <port> |
| Backend   | <port> |
| API       | <port> |
| Postgres  | <port> |
```

### 6. Initialize logbook

Create `~/.spec/<project-name>/<spec-name>/logbook.md` with the header and first entry.

## Phase 1: Plan

### Auto-approve mode (`--auto-approve <plan-path>`)

If invoked with `--auto-approve <path-to-plan-file>`, skip the interactive planning flow entirely:

1. Read the plan file at the given path — it MUST already contain a Context section, files to modify, acceptance criteria, and a verification section. Callers (e.g. `sentry-fix`) are responsible for generating a valid plan before invoking spec.
2. Copy it to `~/.spec/<project-name>/<spec-name>/plan.md`
3. Do NOT enter plan mode, do NOT call ExitPlanMode, do NOT ask the user for approval
4. Log `Plan auto-approved (source: <path>)` in the logbook
5. Proceed directly to Phase 2

This mode exists so automated orchestrators can dispatch spec loops without requiring a human in the planning step. It is NOT available in normal interactive use.

### Interactive mode (default — Lead does this directly)

The lead IS the planner. Do NOT create a planner teammate.

1. Enter plan mode (EnterPlanMode)
2. Explore the codebase — read relevant files, understand existing patterns
3. Produce a plan for the user to review
4. Iterate with the user until they approve
5. Exit plan mode (ExitPlanMode)
6. Save the approved plan to `~/.spec/<project-name>/<spec-name>/plan.md`
7. Log approval in `~/.spec/<project-name>/<spec-name>/logbook.md`

### Planning constraints
- **Minimal scope** — build the smallest thing that works. One feature at a time. If the user says "basic" or "simple", take it literally.
- **Challenge assumptions** — question weak reasoning, point out over-engineering, flag if the user is solving the wrong problem.
- **No speculative features** — if it's not explicitly needed, don't plan for it. No "nice to haves".
- **Simplest implementation** — default to the simplest approach. Don't add abstractions, config layers, or extensibility unless the user asks.
- **Read before planning** — do NOT plan changes to code you haven't read. Understand existing data structures before proposing rewrites.

### Acceptance criteria (required)

Every plan MUST include an `## Acceptance Criteria` section with concrete, testable conditions. The reviewer uses these to decide PASS/FAIL. The autonomous loop cannot complete without all criteria met.

Format:
```markdown
## Acceptance Criteria

- [ ] User can <do X> and sees <Y>
- [ ] API endpoint <path> returns <expected response> when <condition>
- [ ] Error case: when <bad input>, <expected behavior>
- [ ] Performance: <operation> completes in under <threshold>
```

Rules:
- Each criterion must be verifiable by the reviewer (readable from code, runnable as a test, or checkable in the browser)
- No vague criteria like "works correctly" or "handles errors" — be specific about what "works" means
- Include happy path AND at least one edge case
- If the user doesn't provide criteria, the planner proposes them and gets approval

**Only after the user explicitly approves the plan, proceed to Phase 2.**

## Phase 2: Create Team and Implement (Autonomous)

Create a team with two teammates, both with `mode: "bypassPermissions"` so they can run autonomously without blocking on approval prompts:

- **coder** — uses the `coder` agent definition. Implements the approved plan. Mode: `bypassPermissions`.
- **reviewer** — uses the `reviewer` agent definition. Reviews the coder's work. Mode: `bypassPermissions`.

**IMPORTANT: Coder lifecycle management.**
When sending the plan to the coder, include this instruction:
> "After you finish implementation and report results, DO NOT shut down. Stay alive and wait — the reviewer may send you feedback that you need to fix."

The coder must stay alive through the review loop. Only tell it to shut down after review passes.

**ENTERING AUTONOMOUS MODE:** Before sending work to the coder, DM the user:
1. `mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message=":hammer_and_wrench: *[<spec name>]* Implementation started — you can detach now (`Ctrl+O, D`). Next DM when tests pass.")`
2. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`

Send the approved plan to the coder. The coder:
1. Reads all relevant files
2. Implements each step using TDD (RED → GREEN)
3. Parallelizes independent chunks via sub-agents
4. Runs the full test suite
5. Reports completion to lead — BUT STAYS ALIVE

**If the coder reports a plan issue**, DM the user and wait for guidance.

**TRANSITION → Phase 3:** When coder reports completion, do these in order before ANY other work:
1. `mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message=":white_check_mark: *[<spec name>]* Implementation complete — tests passing, moving to review")`
2. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
3. Then proceed to Phase 3

## Phase 3: Review (Autonomous)

Send the coder's work to the reviewer. The reviewer:
1. Reads all changed files + callers
2. Checks architecture, correctness, style
3. Reports PASS / PASS WITH NOTES / FAIL

### Review loop (coder ↔ reviewer):

**If FAIL or PASS WITH NOTES with ISSUEs:**
1. Log the findings in `~/.spec/<project-name>/<spec-name>/logbook.md`
2. Use `SendMessage` to send the reviewer's findings to the **coder** teammate (the coder is still alive)
3. Tell the coder: "Fix these findings, run tests, and report back"
4. Wait for coder to report fixes
5. Send the updated code back to the reviewer for re-review
6. Repeat up to 3 rounds
7. If still failing after 3 rounds:
   1. `mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message=":rotating_light: *[<spec name>]* Blocked — review failed after 3 rounds\n>*Phase:* review\n>*Reason:* <summary of unresolved findings>\n>*Resume:* `zellij attach <session-name>`")`
   2. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
   3. Stop and wait

**TRANSITION → Phase 4:** When reviewer reports PASS, do these in order before ANY other work:
1. `mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message=":tada: *[<spec name>]* Review passed — shipping PR")`
2. Tell the coder it can shut down
3. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
4. Then proceed to Phase 4

## Phase 4: Ship (Autonomous)

Use the `/pr` skill to:
1. Group changes into logical commits
2. Push to a feature branch
3. Create a PR targeting `dev`

**TRANSITION → Phase 4b:** When PR is created, do these in order before ANY other work:
1. `mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message=":link: *[<spec name>]* PR created — <PR URL>, watching CI")`
2. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
3. Then proceed to Phase 4b

## Phase 4b: CI Pipeline Watch (Autonomous)

After the PR is created, CI pipelines run on the PR head. Watch them and only proceed to Phase 5 once they're either all green or intentionally ignored.

### Poll

```bash
gh pr view <number> --json statusCheckRollup
```

Poll every ~4–5 minutes (use `ScheduleWakeup` with `delaySeconds: 270` to stay within the prompt cache window). Do NOT sleep/poll in a tight loop.

### Triage each non-green check

For every check with `conclusion: FAILURE` or `conclusion: TIMED_OUT`, fetch the job log:

```bash
gh api repos/<owner>/<repo>/actions/jobs/<job-id>/logs | tail -200
```

Then classify the failure into one of three buckets:

**Bucket A — Easy fix, do it yourself (no user DM needed):**
- Formatter/linter violations on files *this PR touched* (ruff, prettier, black, eslint-autofix)
- Pre-existing formatter/linter drift on files this PR did NOT touch — apply the exact fix the tool printed, commit as `chore(<scope>): run <tool> on <file> (unblock CI)`, and push. This is common when the branch is behind base.
- Obviously outdated snapshot/fixture updates from deterministic codegen
- Missing migration dependencies you can regenerate mechanically

Fix locally, commit with a clear `chore:` or `fix:` prefix, push, and loop back to polling. **Do NOT open a separate PR** — fix in the same branch.

**Bucket B — Needs real work but still tractable (spawn coder teammate):**
- Real test failures caused by this PR's changes
- Type errors the PR introduced
- Integration test failures with a clear root cause
- Migration conflicts with a new base branch commit

Send the failure log to the coder teammate (still alive from Phase 2/3) with a clear task description. Loop back to polling once the coder reports a fix pushed.

**Bucket C — Hard or ambiguous (DM the user, then stop):**
- Flaky/infra failures you can't reproduce (stop — don't retry blindly)
- Failures in systems this spec doesn't own, with no clear fix
- CI config breakage
- Secret/credential issues
- Any failure where you'd be guessing

```
mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message=":rotating_light: *[<spec name>]* CI blocked — <check name> failing\n>*Failure:* <one-line summary>\n>*Log:* <job URL>\n>*Why stuck:* <reason you can't fix autonomously>\n>*Resume:* `zellij attach <session-name>`")
```

Then log in the logbook and stop. Wait for the user.

### Checks to ignore

- `IN_PROGRESS` checks — just keep polling
- `SKIPPED` checks — normal, ignore
- `NEUTRAL` checks that don't block merge — ignore
- Checks unrelated to the PR (e.g., `detect-changes` skipped paths) — ignore

### DM once per CI round

When you push a fix for a CI failure, DM the user once per round:
```
:wrench: *[<spec name>]* CI fix pushed — <check name> was <one-line reason>, fixed in <sha>. Re-running pipeline.
```

Don't spam — one DM per push, not one per poll.

### Transition to Phase 5

Once all checks are green (or only SKIPPED / NEUTRAL), log and proceed to Phase 5. No Slack DM needed for the transition — Phase 5 will DM when Greptile comments.

## Phase 5: Greptile (Autonomous)

Wait for Greptile to post its review on the PR. Check periodically:
```bash
gh pr view <number> --comments
```

Once Greptile has commented, use the `/react-to-greptile` skill to:
1. Read all Greptile feedback
2. Fix issues locally
3. Push fixes
4. Reply to every thread
5. Tag Greptile for re-review

**Every Greptile iteration MUST produce a Slack DM — no silent rounds.** The user uses these messages as the scoreboard for the autonomous flow. Send a DM at TWO moments per round:

**(a) When Greptile's verdict arrives** (the moment you read the new summary + score):
```
:robot_face: *[<spec name>]* Greptile round N — score X/5
>*Findings:* <brief list, e.g. "2 P1, 1 P2" or "no issues">
>*Next:* <fixing in branch | merging>
```

**(b) When you push the fixup commit** for that round (the moment the new SHA is on the remote):
```
:wrench: *[<spec name>]* Greptile round N fixes pushed — <sha>
>*Changed:* <one-line summary of what was fixed>
>*Re-triggering Greptile for round N+1*
```

Both DMs are required. If a round has no findings (score 5/5 on first pass), send only the (a) DM and then the final DM below. If a round fails to produce a fix (e.g. coder blocked), send the (a) DM then escalate with the blocked DM from the error-handling section.

Log each DM in `~/.spec/<project-name>/<spec-name>/logbook.md`.

If score is 5/5 — **FINAL DM**, before any other work:
1. `mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message=":trophy: *[<spec name>]* Complete — PR ready for human review: <PR URL>")`
2. Log COMPLETE in `~/.spec/<project-name>/<spec-name>/logbook.md`

## Slack DM Protocol

**Every milestone MUST send a Slack DM. This is not optional.** The user relies on these notifications to track progress without watching the terminal.

### Message format

All messages use Slack markdown and emojis for scannability:

```
<emoji> *[<spec name>]* <status> — <description>
```

Emoji per milestone:
- :rocket: — Spec started
- :hammer_and_wrench: — Implementation started
- :white_check_mark: — Implementation complete / tests passing
- :mag: — Review in progress
- :tada: — Review passed
- :link: — PR created
- :robot_face: — Greptile round verdict arrived
- :wrench: — CI / Greptile fix pushed
- :trophy: — Feature complete
- :rotating_light: — Blocked / needs intervention

Examples:
- `:rocket: *[Snake Game]* Spec started — setting up workspace`
- `:hammer_and_wrench: *[Snake Game]* Implementation started — you can detach now (\`Ctrl+O, D\`). Next DM when tests pass.`
- `:white_check_mark: *[Snake Game]* Implementation complete — tests passing, moving to review`
- `:tada: *[Snake Game]* Review passed — shipping PR`
- `:link: *[Snake Game]* PR created — <https://github.com/org/repo/pull/123|#123>, waiting for Greptile`
- `:robot_face: *[Snake Game]* Greptile round 1 — score 3/5, fixing issues`
- `:trophy: *[Snake Game]* Complete — PR ready for human review: <https://github.com/org/repo/pull/123|#123>`
- `:rotating_light: *[Snake Game]* Blocked — test suite failing after 3 review rounds\n>*Phase:* review\n>*Reason:* reviewer found race condition in auth handler that coder can't resolve\n>*Resume:* \`zellij attach spec-snake-game\``

### Tool call

```
mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message="[<spec name>] <status> — <description>")
```

### Milestones that require a DM
- Implementation started (you can detach now)
- Implementation complete, tests passing
- Review passed (or failed after 3 rounds)
- PR created
- Each Greptile round score
- Feature complete
- User intervention required (any error)

## Cleanup — ACCEPTED Phase

When the spec reaches COMPLETE, **nothing is cleaned up automatically**. The worktree, docker resources, and branch all stay alive. The logbook status is `COMPLETE`.

The user must explicitly accept the spec to trigger cleanup. This happens when the user says "accept", "lgtm", "ship it", or "clean up" for a completed spec.

### When the user accepts:

1. Update logbook status to `ACCEPTED`
2. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
3. Clean up docker resources (if any):
   ```bash
   COMPOSE_PROJECT_NAME=spec-<spec-name> docker compose down -v 2>/dev/null || true
   ```
4. Remove the worktree (the branch and PR stay — user merges manually):
   ```
   ExitWorktree(action="remove")
   ```
5. DM the user:
   ```
   mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message=":broom: *[<spec name>]* Accepted — worktree cleaned up. PR ready to merge.")
   ```

### If the user rejects:

Rejection means the spec needs more iteration, NOT deletion. 

1. Update logbook status to `ITERATING`
2. Log the user's feedback in `~/.spec/<project-name>/<spec-name>/logbook.md`
3. Go back to Phase 1 (planning) — the user iterates on the plan with the new feedback
4. The worktree, docker resources, and branch all stay alive

## Error Handling / Intervention Required

When anything needs user intervention, including:
- Errors (test suite broken, git conflict, API error)
- Permission prompts blocking a teammate (e.g., `cd && git` compound commands, unknown tools)
- Coder can't resolve review feedback after retries
- Ambiguous requirements the plan didn't clarify
- Any "Do you want to proceed?" prompt that blocks the autonomous flow

**DM the user immediately with full context:**
```
mcp__claude_ai_Slack__slack_send_message(channel_id="<slack-user-id>", message=":rotating_light: *[<spec name>]* Blocked — <what happened>\n>*Phase:* <current phase>\n>*Reason:* <why it can't continue>\n>*Resume:* `zellij attach <session-name>`")
```

Then:
1. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
2. Stop the loop and wait for the user to come back

The intervention DM must always include:
- **What** went wrong (one line)
- **Phase** it's stuck in (implementing, reviewing, shipping, greptile)
- **Why** it can't continue without the user
- **Resume command** (`zellij attach <session-name>`) so the user can jump straight in

Do NOT retry blindly. Do NOT use destructive git operations to work around issues.