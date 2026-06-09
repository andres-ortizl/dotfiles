---
name: specdex
description: "End-to-end feature development loop. You describe a feature, iterate on the plan, then the team implements, reviews, ships a PR, and handles the configured PR-review bot autonomously. Notifies you at milestones. Use ONLY when the user wants the full autonomous implement→review→PR→verify loop for a multi-file feature. Do NOT use for: quick bug fixes, single-file edits, exploratory/discussion tasks, or anything the user wants to drive step-by-step."
triggers:
  - specdex
---

# specdex: End-to-End Feature Development

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

## Modes

`/specdex` follows the git/gh grammar: **mode = bare verb, modifier = `--flag`, operand = positional.**

| Invocation | Mode |
|---|---|
| `/specdex <feature description>` | default — plan → implement → review → ship → verify |
| `/specdex collaborate <feature>` | human-driven session: registers + badges in the fleet, skips the team/PR automation (see Collaborate) |
| `/specdex resume` | re-attach to the most recent non-terminal spec for this project |
| `/specdex accept` | accept a COMPLETE spec → cleanup |
| `/specdex --auto-approve <plan-path>` | modifier on default mode (non-interactive) |

`/specdex` with no args lists these modes.

## Configuration (personal — fixed stack)

This is a personal companion skill — the stack is fixed, not resolved at runtime:

```bash
NOTIFIER=slack
CI=github-actions
PR_REVIEW=greptile
MUX=zellij
CI_REACTOR=/react-to-pipelines
REVIEW_REACTOR=/react-to-greptile
SHIP_ACTION=/pr
WEBHOOK="$DEX_NOTIFY_WEBHOOK"        # set in env; keep OUT of committed files
```

- **Notify** = `notify "<msg>"` → a `curl` POST to `$WEBHOOK` (Slack-shaped; see Notification Protocol). No webhook → silent no-op. Everywhere this skill says `notify "..."`, that's this.
- **Agent models** — coder/reviewer use their agent-definition `model:` unless overridden at spawn.
- **Skip verify** for a personal vault (no CI/PR review) by jumping straight to COMPLETE after the PR.

## Telemetry + memory interface (injected — not part of this skill)

This skill is **pure orchestration**. The emit + retrieve interface — how milestones get
recorded and how prior memory is pulled — is **injected by an install script built *with*
the brain**, not baked here. The skill names *milestones*; the install wires them to the
interface (a CLI / hooks). Until injected, the `dex <verb>` calls below are harmless no-ops.

Set once at setup:

```bash
export DEX_SPEC=<project-name>/<spec-name>   # once at setup
export DEX_ACTOR=lead                         # coder/reviewer set their own (records WHO)
```

**At each milestone, the injected interface records the matching event** (and every
consequential cross-agent SendMessage records one). `dex <verb>` is the shorthand the
install binds:

| When | Milestone |
|---|---|
| Setup — worktree registered | `dex init --branch specdex-<spec-name> --worktree <path> --session "$CLAUDE_CODE_SESSION_ID"` |
| Setup — ports | `eval "$(dex ports alloc)"` |
| Plan | `dex phase plan` |
| Implement starts | `dex phase build` |
| Coder spawned / idle | `dex agent spawn coder --id <id>` / `dex agent idle coder` |
| Coder green | `dex test --passed <P> --failed <F> --cmd "<cmd>"` |
| Review starts | `dex phase review` then `dex agent spawn reviewer` |
| Each verdict | `dex review --round <N> --verdict pass\|fail\|notes --blockers <b> --issues <i>` |
| Shipping | `dex phase ship` |
| PR created / state | `dex pr --number <N> --url <url> [--state merged\|closed]` |
| Verify starts | `dex phase verify` |
| Each poll cycle | `dex beat` |
| CI check / bot review lands | `dex gate --provider ci\|review --result <result> [--score <0-5>]` |
| Blocked on the human | `dex block "<why>"` (clear with `dex unblock`) |
| COMPLETE / ACCEPTED | `dex phase complete` / `dex phase accepted` |

**Retrieve (consume, don't own):** at Plan, pull prior lessons/gotchas scoped to the touched
files — `dex memory find "<feature> + <paths>"` — and fold them in before writing the plan.
The read side is the whole point of the brain; the skill consumes it, never curates.

## Mode: collaborate (`/specdex collaborate <feature>`)

A **human-driven** session that you still want visible in the fleet. Unlike the default
autonomous loop, you (lead) and the user drive the work directly — no coder/reviewer
team is spawned and there is no autonomous ship/CI loop. It is tracked in the same
registry so it appears alongside the autonomous minions, badged `collaborative`.

1. Setup is lighter: you may work in a new worktree **or** directly on the current
   checkout. Register with the collaborative flag so the fleet badges it apart:
   `dex init --branch <branch> --worktree "$(pwd)" --collaborative`
2. Set `DEX_SPEC` once, then emit phase events as the work actually moves
   (`dex phase plan` → `dex phase build` → …) and `dex beat` at checkpoints so the
   spec reads as alive. Optionally `dex agent spawn lead` to show who's driving.
3. Save the design doc to `~/.spec/<project-name>/<spec-name>/spec.md` (same artifact
   the autonomous loop and the desktop app read).
4. There is no team review/PR automation — the human decides when to ship. If a PR is
   opened, record it (`dex pr …`) and flip its state when merged (see PR state below).
5. Reaching a natural stopping point: `dex phase complete`. Cleanup is the same
   `/specdex accept` path.

This mode does the bookkeeping that makes a hands-on session show up in the fleet — it
does **not** run the autonomous coder/reviewer pipeline.

## Setup

### 0. Session persistence check

The autonomous loop must survive the terminal closing, so it runs inside `zellij` (the
fixed multiplexer — `MUX=zellij`).

The spec session runs inside a named multiplexer session (`spec-<spec-name>`) so it survives
terminal closes and can be re-attached by the desktop "attach in terminal" button. The session
is **created if absent, attached if present** (idempotent) — so re-running setup never spawns
a second claude.

Per-multiplexer attach-or-create and detach:

| MUX | create-or-attach | detach |
|---|---|---|
| zellij | `zellij attach spec-<spec-name> 2>/dev/null \|\| { zellij attach -b -c spec-<spec-name> && zellij --session spec-<spec-name> run -- claude --continue && zellij attach spec-<spec-name>; }` | `Ctrl+O, D` |
| tmux | `tmux new-session -A -s spec-<spec-name>` | `Ctrl+B, D` |

If `$ZELLIJ_SESSION_NAME` is unset (not currently inside zellij), warn before proceeding:

> You're not inside zellij. If you close this terminal, the autonomous loop dies. Start one and re-run `/specdex` inside it — `zellij attach spec-<spec-name>` (detach `Ctrl+O, D`). The loop then keeps running and you'll get notifications at each milestone.

Wait for the user to confirm continue-anyway, or restart inside a multiplexer.

### 0b. Notifications

`notify` is a `curl` POST to the webhook (see Notification Protocol). Send the start notice:

```
notify ":rocket: *[<spec name>]* Spec started — setting up workspace"
```

If `$DEX_NOTIFY_WEBHOOK` is unset, `notify` is a no-op — just continue silently.

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

- **`spec.md`** — the approved plan
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
EnterWorktree(name="specdex-<spec-name>")
```

This creates a new branch and working directory at `.claude/worktrees/specdex-<spec-name>`. All implementation happens here — the main working tree is untouched. The **`specdex-` prefix** makes specdex's worktrees identifiable (`git worktree list | grep '/specdex-'`) so cleanup never touches Conductor/other-tool worktrees, and the UI locates a spec's `.dex.toml` via its recorded worktree path.

### 4. Copy environment

Check for `.spec-env` in the project root. If it exists, copy it silently into the worktree as `.env`. If it doesn't exist, warn once and continue — do NOT block:

> No `.spec-env` found in project root. The worktree won't have any env vars. Create one at the project root if needed.

```bash
cp <original-project-root>/.spec-env .env 2>/dev/null
```

### 5. Assign ports and project name

See **`reference/ports.md`** for the offset-assignment algorithm and the `.env` / `env.md` templates.

### 6. Initialize logbook

Create `~/.spec/<project-name>/<spec-name>/logbook.md` with the header and first entry.

## Plan

### Auto-approve mode (`--auto-approve <plan-path>`)

If invoked with `--auto-approve <path-to-plan-file>`, skip the interactive planning flow entirely:

1. Read the plan file at the given path — it MUST already contain a Context section, files to modify, acceptance criteria, and a verification section. Callers (e.g. `sentry-fix`) are responsible for generating a valid plan before invoking spec.
2. Copy it to `~/.spec/<project-name>/<spec-name>/spec.md`
3. Do NOT enter plan mode, do NOT call ExitPlanMode, do NOT ask the user for approval
4. Log `Plan auto-approved (source: <path>)` in the logbook
5. Proceed directly to Build

This mode exists so automated orchestrators can dispatch spec loops without requiring a human in the planning step. It is NOT available in normal interactive use.

### Interactive mode (default — Lead does this directly)

The lead IS the planner. Do NOT create a planner teammate.

1. Enter plan mode (EnterPlanMode)
2. Explore the codebase — read relevant files, understand existing patterns. **Pull prior memory** scoped to the files you'll touch (`dex memory find "<feature> + <paths>"`, injected — no-op if absent) and fold relevant lessons/gotchas into the plan before writing it
3. Produce a plan for the user to review
4. Iterate with the user until they approve
5. Exit plan mode (ExitPlanMode)
6. Save the approved plan to `~/.spec/<project-name>/<spec-name>/spec.md`
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

**Only after the user explicitly approves the plan, proceed to Build.**

## Build — Create Team & Implement (Autonomous)

Create a team with two teammates, both with `mode: "bypassPermissions"` so they can run autonomously without blocking on approval prompts:

- **coder** — uses the `dex-coder` agent definition. Implements the approved plan. Mode: `bypassPermissions`. Spawn prompt must include: `export DEX_ACTOR=coder` (alongside `DEX_SPEC`).
- **reviewer** — uses the `dex-reviewer` agent definition. Reviews the coder's work. Mode: `bypassPermissions`. Spawn prompt must include: `export DEX_ACTOR=reviewer` (alongside `DEX_SPEC`).

**MANDATORY — pin the worktree in BOTH spawn prompts.** Spawned teammates inherit cwd = the repo root (the MAIN checkout), not your worktree, so a relative-path edit silently lands on `main` instead of the branch. Every spawn prompt MUST carry the absolute worktree path and this rule:

> "Your worktree is `<absolute-worktree-path>`. It is the ONLY valid root: pass it explicitly to every file and git operation (`git -C <absolute-worktree-path> …`), never rely on cwd, never edit by relative path — sub-agents resolve relative paths to the repo root, which is the MAIN checkout, not this worktree. Before you start and again before you report, run `git -C <absolute-worktree-path> status` and confirm the MAIN checkout is clean."

> **Communication model — two planes.** Both teammates have `SendMessage`, so messaging is bidirectional and peer-to-peer (full mesh).
> - **SendMessage = delivery plane** (one-to-one, needs a live recipient). Use it to cut roundtrips: coder/reviewer report to you directly, and the reviewer messages the coder its findings directly (no lead relay). This is the fast lane.
> - **Event log = visibility plane** (one-to-many, async, durable). **Every consequential message MUST also record a matching event via `dex`** (see the Event emission section). This is the rule that keeps cutting the lead out of relays from making the lead — and your Slack scoreboard, the fleet view, the audit trail — blind. Fast lane + the record.
> - **You stay the authority on phase transitions and termination.** Peers coordinate fix-rounds directly, but only YOU decide PASS→ship, max-rounds-hit→escalate, and blocked→DM. Peers iterate; lead decides. This is what prevents an endless coder↔reviewer ping-pong with no one calling it.
> - Report **files** (`coder-report.md`, `review-round-<N>.md`) stay as the durable fallback record, but SendMessage is now the primary, immediate channel — don't poll idle-notifications-then-read-file as the main path.

**IMPORTANT: Coder lifecycle management.**
When sending the plan to the coder, include this instruction:
> "When you finish implementation: (1) `SendMessage` me (the lead) your completion report — per-section summary + the exact test commands you ran with pass/fail counts + deviations + unverified items; (2) also WRITE the same report to `~/.spec/<project-name>/<spec-name>/coder-report.md` as the durable record; (3) record via `dex` (`dex test --passed … --failed …`, then `dex agent idle coder`). Then DO NOT shut down: stay alive and wait. The reviewer may `SendMessage` you findings directly — when it does, apply the fixes, re-run tests, message both me and the reviewer that you're done, overwrite `coder-report.md`, emit the new test result, and stay alive again."

The coder must stay alive through the review loop. Only tell it to shut down after review passes.

**ENTERING AUTONOMOUS MODE:** Before sending work to the coder, DM the user:
1. `notify ":hammer_and_wrench: *[<spec name>]* Implementation started — you can detach now (`Ctrl+O, D`). Next DM when tests pass."`
2. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`

Send the approved plan to the coder. The coder:
1. Reads all relevant files
2. Implements each step using TDD (RED → GREEN) — see `/tdd` for the discipline (vertical slicing, public-interface-only, integration-first, no horizontal batching)
3. Parallelizes independent chunks via sub-agents
4. Runs the full test suite
5. `SendMessage`s its completion report to the lead (and writes `coder-report.md` as the durable copy) — BUT STAYS ALIVE

**If the coder reports a plan issue**, DM the user and wait for guidance.

**TRANSITION → Review:** When the coder SendMessages its completion report (the idle/completion notification is your cue to check the message + `coder-report.md`), confirm tests are green. If not green, SendMessage the coder to finish; don't advance. Once green, do these in order before ANY other work:
1. `notify ":white_check_mark: *[<spec name>]* Implementation complete — tests passing, moving to review"`
2. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
3. Then proceed to Review

## Review (Autonomous)

Spawn the reviewer **as a persistent teammate** (it stays alive across all rounds so it has a live inbox for the coder to message — do NOT re-spawn it per round). Its spawn prompt MUST name the verdict file AND the peer protocol below. The reviewer:
1. Reads all changed files + callers
2. Checks architecture, correctness, style; runs the affected test suites
3. `SendMessage`s its verdict to the lead AND writes `~/.spec/<project-name>/<spec-name>/review-round-<N>.md` — first line `VERDICT: PASS | PASS WITH NOTES | FAIL`, then findings (`[BLOCKER|ISSUE|NIT] file:line — problem — fix`) — and records it via `dex review --round <N> --verdict …`.

### Review loop (coder ↔ reviewer, peer mesh):

The fix-iteration happens **peer-to-peer** to cut the lead-relay roundtrip. The lead does NOT relay findings — it observes (via the verdict messages + the event log) and stays the authority on termination.

**If FAIL or PASS WITH NOTES with ISSUEs**, the reviewer (per its spawn prompt) directly:
1. `SendMessage`s its findings to the **coder** teammate, AND writes them to `~/.spec/<project-name>/<spec-name>/fix-request-<N>.md` as the durable record
2. The coder fixes, re-runs tests, `SendMessage`s the reviewer "done" (and the lead), emits the new test result, stays alive
3. The reviewer re-reviews (same live agent, new `review-round-<N+1>.md`), emits the new verdict
4. The lead counts rounds from the verdict events. Repeat up to 3 rounds.
5. If still failing after 3 rounds (lead decides):
   1. `notify ":rotating_light: *[<spec name>]* Blocked — review failed after 3 rounds\n>*Phase:* review\n>*Reason:* <summary of unresolved findings>\n>*Resume:* `reattach via your multiplexer (zellij attach / tmux attach) <session-name>`"`
   2. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
   3. Stop and wait

**TRANSITION → Ship:** When reviewer reports PASS, do these in order before ANY other work:
1. `notify ":tada: *[<spec name>]* Review passed — shipping PR"`
2. Tell the coder AND the reviewer they can shut down (both are persistent teammates)
3. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
4. Then proceed to Ship

## Ship (Autonomous)

Use the `/pr` skill to:
1. Group changes into logical commits
2. Push to a feature branch
3. Create a PR targeting `dev`

**TRANSITION → Verify:** When PR is created, do these in order before ANY other work:
1. `notify ":link: *[<spec name>]* PR created — <PR URL>, watching CI"`
2. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
3. Then proceed to Verify

## Verify — CI + bot review (Autonomous)

**Skip this phase for a personal vault** (no CI / no PR review) → straight to COMPLETE.
Otherwise two parts: **CI watch** (GitHub Actions) and **bot review** (Greptile). On entry
`dex phase verify`; `dex beat` each poll cycle; record outcomes with `dex gate --provider
ci|review …`. Reactors: `/react-to-pipelines` (CI), `/react-to-greptile` (bot review).

### CI watch

After the PR is created, CI runs on the PR head. Poll until green or intentionally ignored.

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

Run `$CI_REACTOR` (the configured CI reactor skill) and/or send the failure log to the coder teammate (still alive from Build/Review) with a clear task description. Loop back to polling once the fix is pushed.

**Bucket C — Hard or ambiguous (DM the user, then stop):**
- Flaky/infra failures you can't reproduce (stop — don't retry blindly)
- Failures in systems this spec doesn't own, with no clear fix
- CI config breakage
- Secret/credential issues
- Any failure where you'd be guessing

```
notify ":rotating_light: *[<spec name>]* CI blocked — <check name> failing\n>*Failure:* <one-line summary>\n>*Log:* <job URL>\n>*Why stuck:* <reason you can't fix autonomously>\n>*Resume:* `reattach via your multiplexer (zellij attach / tmux attach) <session-name>`"
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

Once all checks are green (or only SKIPPED/NEUTRAL), proceed to bot review.

### Bot review

Wait for Greptile to post its review:
```bash
gh pr view <number> --comments
```

Once it has commented, use **`$REVIEW_REACTOR`** (the provider's registry reactor — e.g.
`/react-to-greptile`, `/react-to-coderabbit`) to: read feedback, fix locally, push,
reply to every thread, re-trigger the bot. Record each round with
`dex gate --provider review --result <pass|fail> --score <0-5>`.

**Every bot-review round MUST produce a notification — no silent rounds** (the user reads
these as the scoreboard). Notify (via `$NOTIFIER`) at TWO moments per round:
- **(a) verdict arrives:** round N, score X/5, findings summary, next action.
- **(b) fixup pushed:** round N fixes pushed `<sha>`, what changed, re-triggering.

If a round passes on the first look, send only (a) then the final notice. If a round
can't be fixed (coder blocked), send (a) then `dex block "<why>"` and escalate.

When the bot reaches its pass threshold → **FINAL**, before any other work:
1. Notify via `$NOTIFIER`: "Complete — PR ready for human review: <PR URL>"
2. `dex phase complete` and log COMPLETE in `~/.spec/<project-name>/<spec-name>/logbook.md`

## Notification Protocol

`WEBHOOK="$DEX_NOTIFY_WEBHOOK"` (Slack incoming-webhook; set in env, keep OUT of committed
files). Everywhere this skill writes `notify "<message>"`, it means:

```bash
notify() {
  [ -z "$WEBHOOK" ] && return 0
  curl -fsS -X POST -H 'Content-Type: application/json' \
    -d "$(jq -n --arg t "$1" '{text:$t}')" "$WEBHOOK" >/dev/null || true
}
```

Fire-and-forget — a failed notification never blocks the loop. See **`reference/slack.md`**
for the message format / emoji table.

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
   notify ":broom: *[<spec name>]* Accepted — worktree cleaned up. PR ready to merge."
   ```

### If the user rejects:

Rejection means the spec needs more iteration, NOT deletion.

1. Update logbook status to `ITERATING`
2. Log the user's feedback in `~/.spec/<project-name>/<spec-name>/logbook.md`
3. Go back to Plan (planning) — the user iterates on the plan with the new feedback
4. The worktree, docker resources, and branch all stay alive

## Error Handling / Intervention Required

See **`reference/errors.md`** for the intervention DM template, the mandatory fields, and the rules (no blind retries, no destructive git).
