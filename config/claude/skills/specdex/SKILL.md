---
name: specdex
description: "End-to-end feature development loop. You describe a feature, iterate on the plan, then the team implements, reviews, ships a PR, and handles the configured PR-review bot autonomously. Notifies you at milestones. Use ONLY when the user wants the full autonomous implement→review→PR→verify loop for a multi-file feature. Do NOT use for: quick bug fixes, single-file edits, exploratory/discussion tasks, or anything the user wants to drive step-by-step."
triggers:
  - specdex
---

# specdex: End-to-End Feature Development

You are the **lead** of a small development team. You plan a feature with the user, then spawn a team of agents (a coder and a reviewer) to drive it from approved plan to a PR that's green and bot-approved — notifying the user only at milestones and when a decision is genuinely his.

# The loop

```
User describes feature
        │
        ▼
┌─ SETUP ───────────────────┐
│  spec dir + worktree       │
│  dex init (register!)      │
│  env + ports               │
└───────┬────────────────────┘
        ▼
┌─ PLAN (interactive) ──────┐
│  Lead enters plan mode     │
│  iterate with user until   │
│  approved → spec.md        │
└───────┬────────────────────┘
        │ plan approved
        ▼
┌─ BUILD (autonomous) ──────┐
│  per-story loop:           │
│  fresh coder per story →   │
│  impl → test → commit →    │
│  per-story review →        │
│  fix-loop (≤3) → next      │
└───────┬────────────────────┘
        │ all stories built + reviewed
        ▼
┌─ FINAL REVIEW (auto) ─────┐
│  persistent reviewer:      │
│  do the stories compose?   │
│  integration gaps? PASS    │
└───────┬────────────────────┘
        │ PASS
        ▼
┌─ SHIP (autonomous) ───────┐
│  /pr: push, open PR → dev  │
└───────┬────────────────────┘
        │ PR created
        ▼
┌─ VERIFY (autonomous) ─────┐
│  CI watch → green          │
│  bot review → pass ≥ 5/5   │
└───────┬────────────────────┘
        │ done
        ▼
     COMPLETE ──(accepted)──▶ docker down
```

# Configuration

Personal companion skill — the stack is **fixed**, not resolved at runtime:

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

- **Agent models** — coder/reviewer use their agent-definition `model:` unless overridden at spawn.
- **Skip Verify** for a setup with no CI/PR review → straight to Complete after the PR.

# Roles

## Lead (you — the main session)

The continuity holder and the **sole authority** on phase transitions, escalation, and termination. You: plan with the user, launch + brief the team, drive the per-story loop, decide PASS→ship, mark stories done, run the ship/verify loop, and are the **only one who notifies the user**. You do **not** implement stories yourself — if you're writing story code, you skipped launching a coder.

## Coder (`dex-coder` agent type)

A **fresh teammate per story** (clean context — the implementation is the rot-prone part). Implements ONE story TDD, commits `feat(<spec>/<id>)`, reports green, then stays alive to fix that story's review findings. Never decides verdicts, never marks completion.

## Reviewer (`dex-reviewer` agent type)

**One persistent teammate** for the whole feature. Reviews each story's diff in turn, runs the affected tests, issues a VERDICT with severity-tagged findings, re-reviews fixes, and does the final integration pass. Never marks a story done.

Both coder and reviewer are **real Claude Code teammates** (own context window, addressable via `SendMessage`), launched through the agent-teams feature — see *The loop & rules → Launching the team*.

# The loop & rules

## Launching the team — the ACTUAL mechanism (do not skip)

Both roles are spawned through the **[agent-teams](https://code.claude.com/docs/en/agent-teams) feature** — not subagents, and **not** `dex` events. You actually launch them: create an agent team and spawn a **named** teammate referencing the agent type — *"spawn a teammate named `reviewer` using the `dex-reviewer` agent type"*, and per story *"spawn a teammate named `coder` using the `dex-coder` agent type"* — handing each its full brief as the spawn prompt.

> **Launching a teammate ≠ `dex agent spawn`.** Launching creates a working Claude instance. `dex agent spawn coder|reviewer` is **only an event record** for the fleet view / audit trail — it launches nothing. Always launch the teammate FIRST, then `dex agent spawn …` to record it. If you're implementing a story yourself instead of through a `coder` teammate, you skipped the launch — stop and spawn it. (This is the single most common failure of this loop.)

**Permissions are inherited, not per-teammate.** Teammates start with **the lead's** permission mode (fixed at spawn). So the loop requires the **lead** to run in bypass (`claude --dangerously-skip-permissions`, which the resume command already uses); every teammate then inherits it. If a first-launch approval prompt appears, dismiss it. **Preconditions:** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and Claude Code ≥ 2.1.32 — agent teams are experimental and OFF by default. If a spawn produces no live teammate, you're in solo-fallback: surface it, don't quietly work alone.

**MANDATORY — every teammate enters the worktree first.** Spawned teammates are *separate* sessions that start at the repo root (the MAIN checkout), not your worktree. Every spawn prompt MUST carry the absolute worktree path and this rule:

> "Your worktree is `<absolute-worktree-path>`. Your session starts at the repo root, NOT there — so **as your FIRST action run `EnterWorktree(path="<absolute-worktree-path>")`** to switch your session into it. After that, bare `git` and relative paths resolve to your branch; confirm with `git status` that you're on `specdex-<spec-name>` before you start. Any sub-agent you spawn also starts at the root — give it the same path and tell it to `EnterWorktree(path=…)` first too. (`git -C <absolute-worktree-path> …` also works from anywhere if you need to be explicit.)"

**Communication — two planes.** Both teammates have `SendMessage` (full mesh): use it to cut roundtrips (reviewer messages the coder findings directly, no lead relay) — that's the fast lane. The **event log is the visibility plane**: every consequential message also records a matching `dex` event. Peers coordinate fix-rounds directly; **only the lead** decides PASS→ship, max-rounds→escalate, blocked→DM.

## The per-story cycle (the coder⇄reviewer pin-pon)

The feature is built and reviewed **one story at a time**, each a self-contained cycle only the lead can end.

```
LEAD      ─ launch a FRESH coder, brief it on THIS story only
CODER     ─ implement (TDD) → commit feat(<spec>/<id>)
            └ ping "green @ <sha>, tests P/F"   →  lead + reviewer
REVIEWER  ─ review the diff + run the tests
            └ ping a VERDICT                     →  lead + coder
                 ├ PASS → LEAD marks `dex story done`, retires the coder → next story
                 └ FAIL → CODER fix → commit fix(<spec>/<id>) → ping again → reviewer re-reviews
                          (≤ 3 review rounds; still failing → LEAD blocks + stops)
```

**The review loop (mesh, ≤ 3 rounds).** The coder stays alive throughout; the lead watches the `dex review` verdicts and is the only one who ends the loop. Each **round N** (1, 2, 3):

- **(a) Coder → lead + reviewer.** Once the round's commit has landed (`feat(<spec>/<id>)` on round 1, `fix(<spec>/<id>)` after — confirm with `git -C <worktree> log --oneline -1`), `SendMessage` "`<id>` green @ `<sha>`, tests P/F" and record `dex test --passed … --failed …`. The coder does **not** emit `dex story done`.
- **(b) Reviewer reviews round N.** Reads `git -C <worktree> show <sha>` + the touched files & their callers, runs the affected tests, writes `~/.spec/<project>/<spec>/review-<id>-<N>.md` (first line `VERDICT: PASS | PASS WITH NOTES | FAIL`, then one `[BLOCKER|ISSUE|NIT] file:line — problem — fix` per finding), records `dex review --round <N> --verdict …`, and `SendMessage`s the verdict to **both** the lead and the coder.
- **(c) Branch on the verdict** (see *Escalation & severity* for what each severity means):
  - **PASS**, or **PASS WITH NOTES whose remaining items are only NITs** → story complete; the lead marks it done.
  - **FAIL**, or **PASS WITH NOTES with any BLOCKER/ISSUE** → the coder (already holding round N's findings) fixes, re-runs the affected tests, commits `fix(<spec>/<id>): <what>`, and loops to round N+1. Peer-to-peer — no lead relay.
- **(d) Ceiling.** ≤ **3 verdicts** (≤ 2 coder fix-iterations). If round 3 still isn't a pass, the lead stops: block + notify + halt. Earlier passed stories are already committed, so resume restarts from this one.

**On a passing verdict the LEAD marks completion** (only the lead ends a story): confirm the passing `dex review` landed, emit `dex story done <id> --commit <sha>` (head sha — the single completion signal, so the fleet view and `dex story next` advance only after review passed), shut the coder down (shutdown request → then `dex agent idle coder`), and advance via `dex story next`.

**Coder brief** (each story's fresh coder gets the worktree rule above plus this in its spawn prompt):
> "Implement ONLY the one Build Story I give you, TDD (RED → GREEN), parallelizing independent chunks via sub-agents. Follow the **Escalation & severity** rules: make reversible (two-way-door) calls yourself and `dex note` your reasoning — don't stall on me for those; but `SendMessage` me any genuine one-way-door decision (irreversible API/schema/data-format/security choice) before you bake it in. Run the affected tests. Commit just this story — `git -C <worktree> commit` message `feat(<spec>/<id>): <name>`. `SendMessage` me (the lead) AND the reviewer a short report (what you built, exact test commands + pass/fail counts, the commit sha, deviations, unverified items) and append it to `~/.spec/<project>/<spec>/coder-report.md`. Record `dex test --passed … --failed …` (do NOT emit `dex story done` — completion is the lead's after review passes). Then STAY ALIVE for this story's review: the reviewer may `SendMessage` findings — fix, re-run tests, commit `fix(<spec>/<id>): <what>`, message both, stay alive. Do NOT emit `dex review` or `dex story done`. Shut down only when I tell you this story passed."

## Stories

Stories are the unit of the build loop and what makes a run **resumable** — each lands as its own commit, so a crashed run picks up at the next un-built one instead of re-running the whole feature in a rotting context.

- **Id `S1..SN`** — the stable key, kept for commits (`feat(<spec>/<id>)`) and resume. A short imperative **name** (≤ ~6 words) doubles as the commit subject; a **one-line summary** describes what it does. (Authoring format lives in *Plan → Build stories*.)
- **Completion = review-passed**, marked by the lead (`dex story done`) — never the coder, never at first commit.
- **Authored once** at plan time and static; live status lives in git + `dex story`, not in the spec.md list.
- **Resume** keys off git history (`feat(<spec>/<id>)` commits exist) and `dex story next` (first non-Done).

## Escalation & severity

The run exists to *finish*. **Default to motion:** the lead and every teammate act on their own judgment — recommended practice, reasonable assumptions, the obvious path — instead of pausing. Don't interrupt the user for anything you can decide.

**The one test for stopping a decision is reversibility** — *how hard is it to change after the feature ships?*

- **Two-way door** — cheap to reverse (naming, internal structure, a swappable library, a flippable default). **Decide it yourself and log it. Never stop for these.**
- **One-way door** — expensive/impossible to undo once shipped (public API/SDK shape, DB schema/migration, persisted data format others depend on, irreversible delete/overwrite, a security boundary, any locked-in external contract). **The only class that stops the user:** the lead notifies with the choice + a recommendation, and waits.

**Log every consequential decision** — the trade for not asking. Lead → `logbook.md`; teammates → `dex note` + their report. Each entry: **what** / **why** / **how** / **reversibility** (`cheap` / `moderate` / `expensive`). If that last field comes out `expensive`, that's the tell it was a one-way door — stop and ask.

**Review finding severity** (drives the per-story loop's branch):

| Severity | Meaning | Effect |
|---|---|---|
| `BLOCKER` | breaks correctness / a stated AC | forces another round |
| `ISSUE` | real defect or risk, must fix | forces another round |
| `NIT` | style/polish, optional | never forces a round; lead may have the coder sweep it |

**Stuck ≠ choosing.** Being genuinely blocked — tests you can't get green, a review that fails its 3-round ceiling, missing access — is different from a decision and **does** stop the run (per-phase paths below). Teammates never DM the user directly: they surface a one-way-door decision or a block to the **lead**, the only one who escalates.

## Events (the substrate)

`dex` is the event substrate: every milestone is recorded as an event → a derived `state.json` that the fleet view and `resume` read. **A spec with no events is invisible** — `resume`, the fleet, and `dex story next` are all blind to a spec that has `spec.md`/`logbook.md` but no `events.jsonl`. So the `dex` calls in each phase below are not optional bookkeeping; they're what makes the spec exist to the system. Full command list: *dex CLI — what & when*.

# Setup

## 0. Session persistence

The autonomous loop must survive the terminal closing, so it runs inside `zellij` (the fixed `MUX`). The session is named `spec-<spec-name>` — **created if absent, attached if present** (idempotent), so re-running setup never spawns a second claude.

| MUX | create-or-attach | detach |
|---|---|---|
| zellij | `zellij attach spec-<spec-name> 2>/dev/null \|\| { zellij attach -b -c spec-<spec-name> && zellij --session spec-<spec-name> run -- claude --continue && zellij attach spec-<spec-name>; }` | `Ctrl+O, D` |
| tmux | `tmux new-session -A -s spec-<spec-name>` | `Ctrl+B, D` |

If `$ZELLIJ_SESSION_NAME` is unset (not inside zellij), warn and wait for the user to confirm continue-anyway or restart inside a multiplexer:

> You're not inside zellij. If you close this terminal, the autonomous loop dies. Start one and re-run `/specdex` inside it — `zellij attach spec-<spec-name>` (detach `Ctrl+O, D`).

## 1. Names + ambient spec

- `<spec-name>`: a short kebab-case slug of the feature (e.g. `auth-middleware`).
- `<project-name>`: the basename of the current project dir (e.g. `anyformat-backend`).

Set the ambient spec so every later `dex` call targets it, and send the start notice:

```bash
export DEX_SPEC=<project-name>/<spec-name>
export DEX_ACTOR=lead
notify ":rocket: *[<spec name>]* Spec started — setting up workspace"
```

## 2. Create spec directory

All specs live at `~/.spec/<project-name>/<spec-name>/` (the single cross-project registry). Holds `spec.md` (approved plan), `logbook.md` (timeline), `env.md` (ports/project record).

```bash
mkdir -p ~/.spec/<project-name>/<spec-name>
```

If it already exists, append a numeric suffix (`<spec-name>-2`, …).

## 3. Worktree + register in the substrate

Check whether cwd is already a worktree (`git rev-parse --is-inside-work-tree && git worktree list`). If it is (e.g. Conductor), **reuse it**. Otherwise create one:

```
EnterWorktree(name="specdex-<spec-name>")
```

This makes a branch + dir at `.claude/worktrees/specdex-<spec-name>` **and switches your (the lead's) cwd into it** — you work here directly for the rest of the run, no `cd` juggling. The `specdex-` prefix keeps cleanup from touching other tools' worktrees and lets the UI find the spec's `.dex.toml`. (Teammates are *separate* sessions that start back at the repo root — they enter the worktree themselves; see *Launching the team*.)

**REQUIRED — register the spec now that the branch + worktree exist.** Until this runs the spec has no `events.jsonl`/`state.json` and is invisible (see *Events*):

```bash
dex init --branch specdex-<spec-name> --worktree <worktree-path> --session "$CLAUDE_CODE_SESSION_ID"
```

(Reused an existing worktree? Pass that branch + path.) This is the spec's first event; everything below appends to the same log.

## 4. Environment

If `.spec-env` exists in the project root, copy it silently into the worktree as `.env`. If not, warn once and continue — don't block.

```bash
cp <original-project-root>/.spec-env .env 2>/dev/null
```

## 5. Ports

If the spec runs local services, allocate ports: `eval "$(dex ports alloc)"`. See **`reference/ports.md`** for the offset algorithm and the `.env`/`env.md` templates. (Record what you allocate — Complete's docker shutdown frees exactly these.)

## 6. Logbook

Create `~/.spec/<project-name>/<spec-name>/logbook.md` with the header and first entry.

# Plan

## Interactive mode (default — lead does this directly)

The lead **is** the planner. Do NOT create a planner teammate.

1. Enter plan mode (`EnterPlanMode`); record `dex phase plan`.
2. Explore the codebase — read relevant files, understand existing patterns, fold in known gotchas before writing the plan.
3. Produce a plan for the user to review.
4. Iterate with the user until they approve.
5. Exit plan mode (`ExitPlanMode`).
6. Save the approved plan to `~/.spec/<project>/<spec>/spec.md`.
7. Log approval in the logbook.

## Auto-approve mode (`--auto-approve <plan-path>`)

For automated orchestrators dispatching loops without a human in planning. NOT for normal interactive use:

1. Read the plan file — it MUST already contain Context, files to modify, `## Acceptance Criteria`, a `## Build Stories` breakdown, and verification.
2. Copy it to `~/.spec/<project>/<spec>/spec.md`.
3. Do NOT enter plan mode, do NOT ask for approval.
4. Log `Plan auto-approved (source: <path>)`; record `dex phase plan`.
5. Proceed directly to Build.

## Planning constraints

- **Minimal scope** — build the smallest thing that works, one feature at a time. Take "basic"/"simple" literally.
- **Challenge assumptions** — flag weak reasoning, over-engineering, solving the wrong problem.
- **No speculative features** — if not explicitly needed, don't plan it.
- **Simplest implementation** — no abstractions/config layers/extensibility unless asked.
- **Read before planning** — don't plan changes to code you haven't read.

## Acceptance criteria (required)

Every plan MUST include an `## Acceptance Criteria` section with concrete, testable conditions — the reviewer uses these to decide PASS/FAIL. The loop cannot complete without all met.

```markdown
## Acceptance Criteria

- [ ] User can <do X> and sees <Y>
- [ ] API endpoint <path> returns <expected> when <condition>
- [ ] Error case: when <bad input>, <expected behavior>
```

Each criterion must be verifiable (readable from code, runnable as a test, checkable in the browser); no vague "works correctly". Include a happy path AND at least one edge case. If the user gives none, propose them and get approval.

## Build stories (required)

Decompose the approved plan into an ordered `## Build Stories` list in `spec.md`:

```markdown
## Build Stories

- S1 — **<imperative name>**: <one-line summary of what it does> _(satisfies AC #1, #2)_
- S2 — **<imperative name>**: <one-line summary> _(satisfies AC #3)_
```

- Each story **independently committable** and small enough for one focused coder pass; order so each builds on the last.
- Every story maps to ≥1 Acceptance Criterion; together they cover all.
- **Don't over-decompose** — a genuinely small feature is a single story `S1`.

**Only after the user explicitly approves the plan, proceed to Build.**

# Build

The autonomous heart — runs the per-story cycle (*The loop & rules → The per-story cycle*).

**Enter.** `dex phase build`. **Launch the persistent `reviewer` teammate once** (agent type `dex-reviewer` — see *Launching the team*), then record it with `dex agent spawn reviewer`. **Register the stories** (`dex story add --id <id> --title "<name>" --summary "<summary>"` for each `## Build Stories` entry). Then notify build-started and tell the user they can detach:

```
notify ":hammer_and_wrench: *[<spec name>]* Build started — per-story loop. You can detach now (Ctrl+O, D). Next DM on review FAILs, blocks, or the final-review pass."
```

**Run the loop.** Loop over `dex story next` (`<id> <title>`; until empty/exit 1):

1. `dex story start <id>` + `dex beat` (heartbeat — keeps the spec reading `alive`; emit one each iteration).
2. **Launch a FRESH `coder` teammate for THIS story** (agent type `dex-coder` — see *Launching the team*), then `dex agent spawn coder --id <id>`. Brief it with the worktree rule + the coder brief + this story's id/name/AC/files. One story only.
3. Run the **review loop** for the story (the (a)–(d) protocol in *The per-story cycle*).
4. On a passing verdict, the **lead** marks `dex story done`, retires the coder, advances.

## Final integration review

When `dex story next` is empty (every story built + reviewed), `dex phase review` and have the **persistent reviewer** do ONE light pass for **cross-story coherence** — do the stories compose, are there integration gaps the per-story diffs couldn't see? It does NOT re-review each diff. Same `dex review` mechanism, written to `review-final.md`; same 3-round ceiling — route fixes to a **fresh coder** (per-story coders have shut down), committing `fix(<spec>/integration): <what>`.

**On PASS → Ship**, in order: `notify ":tada: *[<spec name>]* All stories built + reviewed — shipping PR"` → tell the reviewer to shut down (`dex agent idle reviewer`) → log → proceed to Ship.

**Blocked** (a per-story 3-round failure OR a final-review block):
```
notify ":rotating_light: *[<spec name>]* Blocked — <story <id> | final review> failed after 3 rounds\n>*Phase:* <build | review>\n>*Reason:* <unresolved findings>\n>*Resume:* `zellij attach / tmux attach <session-name>`"
```
Then `dex block "<why>"`, log, and stop.

# Ship

On entry, `dex phase ship`. The build loop already committed each story, so the branch *is* the per-story commits and the tree is clean. Use the `/pr` skill to:

1. Push the branch (its commit step is a no-op when nothing is staged). If `/pr` finds uncommitted changes, treat it as a bug — investigate before pushing.
2. Create a PR targeting `dev`.

**Transition → Verify**, in order:
1. `dex pr --number <N> --url <PR URL>` (records the spec↔PR link in `state.pr`).
2. `notify ":link: *[<spec name>]* PR created — <PR URL>, watching CI"`.
3. Log, then proceed to Verify.

# Verify — CI + bot review

Two parts: **CI watch** then **bot review**. On entry `dex phase verify`; `dex beat` each poll cycle; record outcomes with `dex gate --provider ci|review …`.

## CI watch

Poll the PR head until green or intentionally ignored — every ~4–5 min via `ScheduleWakeup` (`delaySeconds: 270` to stay in the prompt-cache window); never tight-loop.

```bash
gh pr view <number> --json statusCheckRollup
```

For every check `FAILURE`/`TIMED_OUT`, fetch the log (`gh api repos/<owner>/<repo>/actions/jobs/<job-id>/logs | tail -200`) and classify:

- **Bucket A — fix it yourself (no DM).** Formatter/linter violations (touched or drifted files — apply the tool's exact fix, commit `chore(<scope>): run <tool> … (unblock CI)`), deterministic snapshot/fixture updates, regenerable migration deps. Fix in the SAME branch, push, loop back.
- **Bucket B — real work, still tractable.** Real test failures / type errors this PR introduced, integration failures with a clear cause, migration conflicts. Run `$CI_REACTOR`, or spawn a fresh coder with the failure log. Loop back once pushed.
- **Bucket C — hard/ambiguous → DM then stop.** Flaky/infra you can't reproduce, failures in systems this spec doesn't own, CI-config breakage, secrets, anything you'd be guessing at:
  ```
  notify ":rotating_light: *[<spec name>]* CI blocked — <check> failing\n>*Failure:* <one-line>\n>*Log:* <job URL>\n>*Why stuck:* <reason>\n>*Resume:* `zellij attach / tmux attach <session-name>`"
  ```
  Then log and wait.

Ignore `IN_PROGRESS` (keep polling), `SKIPPED`/`NEUTRAL` non-blocking, and unrelated checks. **One DM per CI fix push** (`:wrench: … fixed in <sha>, re-running`), not per poll. Once green → bot review.

## Bot review

Wait for Greptile to comment (`gh pr view <number> --comments`), then use `$REVIEW_REACTOR` to read feedback, fix locally, push, reply to every thread, re-trigger. Record each round `dex gate --provider review --result <pass|fail> --score <0-5>`.

**Every round MUST notify — no silent rounds** (it's the user's scoreboard): (a) verdict arrives (round N, score X/5, findings, next action), and (b) fixup pushed (round N fixes `<sha>`, what changed, re-triggering). A round the coder can't fix → (a), then `dex block "<why>"` and escalate.

On the pass threshold → **Complete**.

# Complete

When the bot passes its threshold, before any other work:
1. `notify` "Complete — PR ready for human review: <PR URL>".
2. `dex phase complete`, log `COMPLETE`.

The PR + branch stay for the human to merge. **Nothing else is cleaned up automatically.**

## Acceptance (frees the ports)

The spec is **accepted** when the work is approved — the user says so ("accept" / "lgtm" / "ship it"), **or the lead declares it** (accepting a clean COMPLETE is a two-way door the lead may take per *Escalation & severity*). On acceptance:

1. `dex phase accepted`, log `ACCEPTED`.
2. If the spec started docker/ports, shut them down (this is the point of acceptance — it frees the ports assigned at Setup):
   ```bash
   COMPOSE_PROJECT_NAME=spec-<spec-name> docker compose down -v 2>/dev/null || true
   ```
3. `notify ":broom: *[<spec name>]* Accepted — docker down, ports freed. PR ready to merge."`

The worktree + branch stay (merging is manual) — no worktree cleanup.

# Modes

Default `/specdex <feature>` runs the whole loop above. `--auto-approve <plan-path>` is a modifier (see *Plan*). Two non-default modes:

## collaborate (`/specdex collaborate <feature>`)

A **human-driven** session you still want visible in the fleet — you and the user drive the work directly, no coder/reviewer team, no autonomous ship/CI loop.

1. Lighter setup: a new worktree **or** the current checkout. Register with the collaborative flag: `dex init --branch <branch> --worktree "$(pwd)" --collaborative`.
2. Set `DEX_SPEC`, then emit phase events as work actually moves (`dex phase plan` → `dex phase build` → …) and `dex beat` at checkpoints. Optionally `dex agent spawn lead`.
3. Save the design doc to `~/.spec/<project>/<spec>/spec.md`.
4. No team review/PR automation — the human decides when to ship; if a PR opens, record it (`dex pr …`).
5. A natural stopping point: `dex phase complete`.

## resume (`/specdex resume`)

Re-attach to the most recent non-terminal spec for this project and continue from **durable state, not a remembered context**. Read the phase (`dex ls` / `state.json`), then:

- **`build`:** find which stories are built from git (`git -C <worktree> log --oneline --fixed-strings --grep "feat(<spec>/"`); the first Build Story not in that set is next (`dex story next`). **Launch a FRESH coder** and run the per-story loop from there — the fresh coder is the whole point.
- **`review` / `ship` / `verify`:** re-enter that phase (re-launch the reviewer if needed, re-poll CI/bot). Committed work + recorded gates are the truth.
- **None found:** tell the user there's nothing to resume; list recent specs (`dex ls`).

# Notifications

All user-facing pings go through `notify` (`$NOTIFIER` = slack via `$WEBHOOK`). Fire-and-forget — a failed notification never blocks the loop; no webhook → silent no-op.

## When to notify Andrew (the Lord Sith)

He reads these as the scoreboard + the things needing him — nothing else.

**DO notify:**
- Spec start, build start (first story), PR created, COMPLETE.
- Every **bot-review round** (verdict + each fixup push) — no silent rounds.
- **Review FAILs / blocks** — a 3-round story failure, a final-review block, a CI Bucket-C stop.
- Any **one-way-door escalation** (*Escalation & severity*) — the choice + your recommendation, then wait.
- Acceptance (docker down).

**Do NOT notify:**
- Every passing story (notify only the first), routine progress, polls, two-way-door decisions (log those in the logbook / `dex note` instead).

## The `notify()` impl

`WEBHOOK="$DEX_NOTIFY_WEBHOOK"` (Slack incoming-webhook; env-set, kept OUT of committed files). Everywhere this skill writes `notify "<message>"`:

```bash
notify() {
  [ -z "$WEBHOOK" ] && return 0
  curl -fsS -X POST -H 'Content-Type: application/json' \
    -d "$(jq -n --arg t "$1" '{text:$t}')" "$WEBHOOK" >/dev/null || true
}
```

See **`reference/slack.md`** for the message format / emoji table.

# dex CLI — what & when

`dex` is the telemetry substrate (events → derived state the fleet + resume read). Set `DEX_SPEC` once at setup and `DEX_ACTOR` per agent (lead/coder/reviewer — records WHO). This whole section is **scoped and removable**: every `dex` call is a harmless no-op if the binary is absent, so dropping this table decouples the skill from the substrate.

| When (milestone) | Command |
|---|---|
| Setup — register the spec | `dex init --branch specdex-<spec-name> --worktree <path> --session "$CLAUDE_CODE_SESSION_ID"` |
| Setup — ports | `eval "$(dex ports alloc)"` |
| Plan entered | `dex phase plan` |
| Build starts | `dex phase build` |
| Stories registered | `dex story add --id <id> --title "<name>" --summary "<summary>"` (one per Build Story) |
| Story started / done | `dex story start <id>` / `dex story done <id> --commit <sha>` (done = lead, on pass) |
| Next un-built story | `dex story next` |
| Heartbeat (each loop/poll) | `dex beat` |
| Coder/reviewer launched·idle | `dex agent spawn coder --id <id>` / `dex agent spawn reviewer` / `dex agent idle <role>` |
| Coder green | `dex test --passed <P> --failed <F> --cmd "<cmd>"` |
| Each review verdict | `dex review --round <N> --verdict pass\|fail\|notes --blockers <b> --issues <i>` |
| Final integration review | `dex phase review` |
| Shipping | `dex phase ship` |
| PR created / state | `dex pr --number <N> --url <url> [--state merged\|closed]` |
| Verify starts | `dex phase verify` |
| CI / bot gate lands | `dex gate --provider ci\|review --result <result> [--score <0-5>]` |
| Decision / note | `dex note --level <l> --topic <t> --text "<…>"` |
| Blocked on the human | `dex block "<why>"` (clear with `dex unblock`) |
| COMPLETE / ACCEPTED | `dex phase complete` / `dex phase accepted` |

# Error handling / intervention

See **`reference/errors.md`** for the intervention DM template, the mandatory fields, and the rules (no blind retries, no destructive git).
