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
│  Per-story loop:          │
│  fresh coder per story    │
│  impl→test→commit→        │
│  per-story review,        │
│  fix-loop (max 3)→next    │
└───────┬───────────────────┘
        │ all built+reviewed
        ▼
┌─ FINAL REVIEW (auto) ────┐
│  Persistent reviewer:     │
│  do the stories           │
│  compose? integration     │
│  gaps the diffs missed?   │
│  PASS → ship              │
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
| `/specdex <feature description>` | default — plan → build (per-story implement + review) → ship → verify |
| `/specdex collaborate <feature>` | human-driven session: registers + badges in the fleet, skips the team/PR automation (see Collaborate) |
| `/specdex resume` | re-attach to the most recent non-terminal spec for this project |
| `/specdex supervise` | external watchdog: resume stale build-phase specs with un-built stories (run on a schedule) |
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
| Stories registered | `dex story add --id <id> --title "<name>" --summary "<summary>"` (one per Build Story, at plan→build) |
| Story started / done | `dex story start <id>` / `dex story done <id> --commit <sha>` |
| Coder spawned / idle | `dex agent spawn coder --id <id>` / `dex agent idle coder` |
| Coder green | `dex test --passed <P> --failed <F> --cmd "<cmd>"` |
| Reviewer spawned (once, at build start) | `dex agent spawn reviewer` |
| Final integration review | `dex phase review` |
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

## Mode: resume (`/specdex resume`)

Re-attach to the most recent non-terminal spec for this project and continue from **durable state, not a remembered context**. Read the spec's phase (`dex ls` / its `state.json`), then:

- **Phase `build`:** read the `## Build Stories` list from `spec.md` and find which are already built — the durable signal is git history: story `<id>` is done iff a `feat(<spec-name>/<id>):` commit exists on the branch. Run `git -C <worktree> log --oneline --fixed-strings --grep "feat(<spec-name>/"` (`--fixed-strings` so the literal `(` isn't treated as a regex), collect the built `<id>`s from those subjects, and the first Build Story not in that set is the next un-built one (`dex story next` returns it directly once the CLI is wired). **Spawn a FRESH coder** (clean context) and run the Build loop from that story. The fresh coder is the whole point — resume exists because the previous context may be dead or rotted.
- **Phase `review` / `ship` / `verify`:** re-enter that phase's loop below (re-spawn the reviewer if needed, re-poll CI / bot review). Committed work and recorded gate results are the source of truth.
- **No non-terminal spec found:** tell the user there's nothing to resume and list recent specs (`dex ls`).

## Mode: supervise (`/specdex supervise`)

The autonomous loop lives inside the lead session. If that session dies (crash, context
exhaustion, a closed multiplexer), nothing restarts it — the spec just goes stale mid-build.
`supervise` is the **external engine** that fixes that: a stateless watchdog meant to run on a
schedule (`/schedule` cron, or `/loop 10m /specdex supervise`), independent of any lead.

Each run:
1. `dex ls --json` — the whole fleet as JSON (each row carries `phase`, `health`,
   `stories_done`, `stories_total`).
2. Pick **resume candidates**: rows where `phase == "build"` AND `health == "stale"` AND
   `stories_done < stories_total`. Skip terminal/healthy specs, anything `blocked`
   (`needs-you` is the human's, never auto-resumed), and specs with no story breakdown
   (`stories_total == 0` — can't be safely resumed headlessly). Stale `review`-phase specs
   (a crashed final integration review) are likewise left for the human — supervise resumes
   only `build`.
3. For each candidate, **resume from durable state** by launching `/specdex resume` into its
   session: `zellij --session spec-<spec-name> run -- claude --dangerously-skip-permissions -p "/specdex resume"`
   (or the `tmux` equivalent). That spawns a FRESH coder on the next un-built story
   (`dex story next`). One resume per candidate per run — the `stale` health threshold is the
   guard against double-spawning a lead for a merely-slow spec.
4. `notify` once per spec resumed (`:recycle: *[<spec>]* resumed — was stale at <done>/<total>
   stories, fresh coder on <next id>`) and `dex note` it so the action shows in the feed.

The supervisor only ever RESUMES — it never plans, ships, or decides. It is the restart
engine; the lead is still the brain.

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

1. Read the plan file at the given path — it MUST already contain a Context section, files to modify, acceptance criteria, a `## Build Stories` breakdown, and a verification section. Callers (e.g. `sentry-fix`) are responsible for generating a valid plan before invoking spec.
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

### Build stories (required)

Decompose the approved plan into an ordered `## Build Stories` list in `spec.md` — the unit of work the Build loop implements and commits one at a time. This is what makes a run **resumable**: each story lands as its own commit, so a crashed or re-attached run picks up at the next un-built story instead of re-running the whole feature in one rotting context.

```markdown
## Build Stories

- S1 — **<imperative name>**: <one-line summary of what it does> _(satisfies AC #1, #2)_
- S2 — **<imperative name>**: <one-line summary> _(satisfies AC #3)_
```

Each story carries three things: the `S1..SN` **id** (the stable key, kept for commits and resume), a short imperative **name** (≤ ~6 words — it doubles as the commit subject `feat(<spec-name>/<id>): <name>`), and a **one-line summary** describing what it does. `dex story ls` renders them as a clean `1..N` numbered list with the summary underneath.

Rules:
- Each story must be **independently committable** and small enough to finish in one focused coder pass. Order them so each builds on the last.
- Every story maps to one or more Acceptance Criteria; together the stories must cover all of them.
- **Don't over-decompose.** A genuinely small feature is a single story `S1` — forcing a breakdown is the same over-engineering the planning constraints forbid. Split only when the feature has several independent slices or won't fit one comfortable context.
- The list is **authored once** at plan time and stays static; live per-story status lives in git (the per-story commits) / `dex story`, not in this list — don't rewrite it mid-run.

**Only after the user explicitly approves the plan, proceed to Build.**

## Build & Review — per-story loop (Autonomous)

The feature is built **and reviewed one Build Story at a time**. You (the lead) are the continuity holder across all stories and the sole authority on termination. Two roles:

- **reviewer** — a teammate of agent type `dex-reviewer`, launched **ONCE** and kept alive for the whole feature. It reviews each story's diff in turn (small, focused diffs) and accumulates cross-story consistency. Spawn prompt includes `export DEX_ACTOR=reviewer`.
- **coder** — a teammate of agent type `dex-coder`, launched **FRESH for each story** (clean context — the implementation is the rot-prone part, so a resumed or crashed story gets a brand-new coder, never a poisoned one). Spawn prompt includes `export DEX_ACTOR=coder`.

### Launching the team — the ACTUAL mechanism (do not skip)

Both roles are **real Claude Code teammates spawned through the [agent-teams](https://code.claude.com/docs/en/agent-teams) feature** — not subagents, and **not** `dex` events. You (the lead) actually launch them: create an agent team and spawn a **named** teammate that references the agent type — *"spawn a teammate named `reviewer` using the `dex-reviewer` agent type"*, and per story *"spawn a teammate named `coder` using the `dex-coder` agent type"* — handing each the full brief (the worktree rule + its role brief below) as its spawn prompt. Each teammate then runs in its own context window and is addressable by name via `SendMessage`. **If you ever find yourself implementing a story yourself instead of through a `coder` teammate, you skipped the launch — stop and spawn it.** (This is the single most common failure of this loop.)

> **Launching a teammate ≠ `dex agent spawn`.** Launching the teammate (above) is the real thing that creates a working Claude instance. `dex agent spawn coder|reviewer` is **only an event record** for the fleet view / audit trail — it launches nothing. Always launch the teammate FIRST, then run `dex agent spawn …` to record it.

**Permissions are inherited, not per-teammate.** Teammates start with **the lead's** permission mode (fixed at spawn — there is no per-teammate mode). So the autonomous loop requires the **lead** to run in bypass (`claude --dangerously-skip-permissions`, which the supervisor's resume command already uses); every teammate then inherits it. If a first-launch approval prompt still appears for a teammate, dismiss it. **Preconditions** (verify before relying on this): `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set and Claude Code is ≥ 2.1.32 — agent teams are experimental and OFF by default. If a spawn produces no live teammate, you are in solo-fallback: surface it, don't quietly do the work alone.

**MANDATORY — pin the worktree in EVERY spawn prompt** (the reviewer's, and every per-story coder's). Spawned teammates inherit cwd = the repo root (the MAIN checkout), not your worktree, so a relative-path edit silently lands on `main` instead of the branch. Every spawn prompt MUST carry the absolute worktree path and this rule:

> "Your worktree is `<absolute-worktree-path>`. It is the ONLY valid root: pass it explicitly to every file and git operation (`git -C <absolute-worktree-path> …`), never rely on cwd, never edit by relative path — sub-agents resolve relative paths to the repo root, which is the MAIN checkout, not this worktree. Before you start and again before you report, run `git -C <absolute-worktree-path> status` and confirm the MAIN checkout is clean."

> **Communication model — two planes.** Both teammates have `SendMessage`, so messaging is bidirectional and peer-to-peer (full mesh).
> - **SendMessage = delivery plane** (one-to-one, needs a live recipient). Use it to cut roundtrips: coder/reviewer report to you directly, and the reviewer messages the coder its findings directly (no lead relay). This is the fast lane.
> - **Event log = visibility plane** (one-to-many, async, durable). **Every consequential message MUST also record a matching event via `dex`** (see the Event emission section). This is the rule that keeps cutting the lead out of relays from making the lead — and your Slack scoreboard, the fleet view, the audit trail — blind. Fast lane + the record.
> - **You stay the authority on phase transitions and termination.** Peers coordinate fix-rounds directly, but only YOU decide PASS→ship, max-rounds-hit→escalate, and blocked→DM. Peers iterate; lead decides. This is what prevents an endless coder↔reviewer ping-pong with no one calling it.
> - Report **files** (`coder-report.md`, `review-round-<N>.md`) stay as the durable fallback record, but SendMessage is now the primary, immediate channel — don't poll idle-notifications-then-read-file as the main path.

**Per-story coder brief.** Each story's fresh coder gets the worktree rule above plus this contract in its spawn prompt:
> "Implement ONLY the one Build Story I give you, TDD (RED → GREEN), parallelizing independent chunks via sub-agents. Run the affected tests. Commit just this story — `git -C <worktree> commit` message `feat(<spec-name>/<id>): <title>`. `SendMessage` me (the lead) AND the reviewer a short report — what you built, the exact test commands + pass/fail counts, the commit sha, deviations, unverified items — and append it to `~/.spec/<project-name>/<spec-name>/coder-report.md`. Record via `dex` (`dex test --passed … --failed …`, then `dex story done <id> --commit <sha>`). Then STAY ALIVE for this story's review: the reviewer may `SendMessage` you findings — fix, re-run tests, commit `fix(<spec-name>/<id>): <what>`, message both me and the reviewer, stay alive. Do NOT emit `dex review` — recording verdicts is the reviewer's job. Shut down only when I tell you this story passed."

**ENTERING AUTONOMOUS MODE.** On `dex phase build`: **launch** the persistent `reviewer` teammate once (agent type `dex-reviewer` — see *Launching the team* above), then record it with `dex agent spawn reviewer`; register the stories (`dex story add --id <id> --title "<name>" --summary "<summary>"` for each `## Build Stories` entry), then DM the user:
1. `notify ":hammer_and_wrench: *[<spec name>]* Build started — per-story loop. You can detach now (`Ctrl+O, D`). Next DM on review FAILs, blocks, or the final-review pass."`
2. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`

**The per-story loop (lead-driven).** Loop over `dex story next` (`<id> <title>`; until it exits empty / exit 1):

1. `dex story start <id>`.
2. **Launch a FRESH `coder` teammate for THIS story** (agent type `dex-coder`, clean context — see *Launching the team* above), then record `dex agent spawn coder --id <id>`. If a first-launch approval prompt appears, dismiss it. Brief it with the worktree rule + the per-story coder brief above + this story's id, title, the Acceptance Criteria it covers, and the relevant files. One story only — never the whole plan.
3. **Per-story review (mesh).** When the coder reports green + the `feat(<spec-name>/<id>)` commit landed (`git -C <worktree> log --oneline -1`) + it emitted `dex story done`, the persistent reviewer reviews THAT story's diff (`git -C <worktree> show <sha>` + the touched files & their callers), runs the affected tests, and `SendMessage`s a verdict to the lead AND the coder — writing `~/.spec/<project-name>/<spec-name>/review-<id>-<round>.md` (first line `VERDICT: PASS | PASS WITH NOTES | FAIL`, then `[BLOCKER|ISSUE|NIT] file:line — problem — fix`) and recording `dex review --round <N> --verdict …`.
   - **FAIL / PASS WITH NOTES with ISSUEs:** the reviewer `SendMessage`s findings straight to the story-coder (peer mesh, no lead relay); the coder fixes, re-tests, commits `fix(<spec-name>/<id>): <what>`, messages both; the reviewer re-reviews. Up to **3 rounds per story** (the lead counts from the verdict events and is the sole authority on giving up).
   - **3 rounds still failing (lead decides):** block + notify + stop — see the blocked template below.
4. **On PASS:** confirm `dex story done <id>` landed, tell THIS story's coder to shut down (`dex agent idle coder`), and move to the next story. Notify on the first story, then only on review FAILs/blocks — don't DM every passing story.

Within a story the coder follows `/tdd` discipline (vertical slicing, public-interface-only, integration-first, no horizontal batching). **If a coder reports a plan issue** mid-loop, DM the user and wait — every passed story is already committed, so the loop resumes from the next one once unblocked.

### Final integration review

When `dex story next` exits empty (every story built + reviewed), `dex phase review` and have the **persistent reviewer** do ONE light pass for **cross-story coherence** — do the stories compose, are there integration gaps the per-story diffs couldn't see? It does NOT re-review each story's diff. Verdict + findings via the same `dex review` mechanism, written to `review-final.md`; same 3-round fix ceiling if it surfaces blockers — route fixes to a **fresh coder** (the per-story coders have shut down), committing `fix(<spec-name>/integration): <what>`.

**TRANSITION → Ship:** When the final integration review is PASS, do these in order before ANY other work:
1. `notify ":tada: *[<spec name>]* All stories built + reviewed — shipping PR"`
2. Tell the reviewer to shut down (`dex agent idle reviewer`)
3. Log in `~/.spec/<project-name>/<spec-name>/logbook.md`
4. Then proceed to Ship

**Blocked template** (a per-story 3-round failure OR a final-review block):
```
notify ":rotating_light: *[<spec name>]* Blocked — <story <id> | final review> failed after 3 rounds\n>*Phase:* <build | review>\n>*Reason:* <summary of unresolved findings>\n>*Resume:* `reattach via your multiplexer (zellij attach / tmux attach) <session-name>`"
```
then `dex block "<why>"`, log in the logbook, and stop.

## Ship (Autonomous)

The Build loop already committed each story (`feat(<spec-name>/<id>): …`), so the branch history *is* the per-story commits and the working tree is clean. Use the `/pr` skill to:
1. Push the branch (its commit step is a no-op when nothing is staged). If `/pr` finds uncommitted changes here, treat it as a bug — a story commit missed something — and investigate before pushing.
2. Create a PR targeting `dev`

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

Run `$CI_REACTOR` (the configured CI reactor skill), or spawn a fresh coder (the per-story coders have shut down by now) and send it the failure log with a clear task description. Loop back to polling once the fix is pushed.

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
