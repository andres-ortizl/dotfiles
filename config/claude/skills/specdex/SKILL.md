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
│  iterate w/ user → spec.md │
│  librarian → context.md    │
└───────┬────────────────────┘
        │ plan approved
        ▼
┌─ BUILD (autonomous) ──────┐
│  per-epic standing pair:   │
│  each story → impl → test  │
│  → commit → review gate →  │
│  fix-loop (≤3) → next story│
│  recycle pair at epic end  │
└───────┬────────────────────┘
        │ all stories built + reviewed
        ▼
┌─ FINAL REVIEW (auto) ─────┐
│  fresh reviewer:           │
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
WEBHOOK="${DEX_NOTIFY_WEBHOOK:-$(grep -m1 '^DEX_NOTIFY_WEBHOOK=' ~/code/dotfiles/apps/specdex/.env 2>/dev/null | cut -d= -f2-)}"   # canonical home: apps/specdex/.env (gitignored); env export overrides
```

- **Agent models** — coder/reviewer use their agent-definition `model:` unless overridden at spawn.
- **Skip Verify** for a setup with no CI/PR review → straight to Complete after the PR.

# Roles

## Lead (you — the main session)

The continuity holder and the **sole authority** on phase transitions, escalation, and termination. You: plan with the user, launch + brief the team, drive the per-epic loop (briefing the standing pair story by story), decide PASS→ship, mark stories done, run the ship/verify loop, and are the **only one who notifies the user**. You do **not** implement stories yourself — if you're writing story code, you skipped launching a coder.

## Coder (`dex-coder` agent type)

**One standing teammate per *epic*** (not per story) — launched once and kept alive across all the epic's stories, so it never re-orients between them. Implements the epic's stories ONE AT A TIME, TDD, each its own commit `feat(<spec>/<id>)`; reports green per story and stays alive to fix that story's review findings. On launch it **reads `context.md`** instead of cold-reading the codebase. The lead recycles it (a fresh instance) only at an **epic boundary** or on a **context-bloat** signal. Never decides verdicts, never marks completion.

## Reviewer (`dex-reviewer` agent type)

**The coder's standing partner for the epic** — launched alongside it and kept alive across the epic's stories. The **per-story review gate stays**: it reviews EACH story's diff as it lands (the rot-prone part is caught here), runs the affected tests, issues a VERDICT with severity-tagged findings, and re-reviews that story's fixes across the round loop. Reads `context.md` on launch. Recycled with the coder at an epic boundary or on bloat. The final cross-story integration pass still gets its **own fresh reviewer** (clean context for the holistic read). Never marks a story done.

## Librarian (an `Explore` agent — plan-time only)

A read-only agent the lead spawns **once during Plan** to dig through the codebase and write **`context.md`**, the feature's shared onboarding doc (subsystem map, key files by symbol, conventions, decisions — see *The shared context doc*). It does the exploration the lead would otherwise re-explain in every spawn brief. It runs once, writes no code, and exits; thereafter `context.md` stays current via one-line per-story deltas (the coder appends its own).

Coder and reviewer are **real Claude Code teammates** (own context window, addressable via `SendMessage`) — spawned per the harness-appropriate mechanism in *The loop & rules → Launching the team*. The librarian is a plain read-only subagent, not a team member.

# The loop & rules

## Launching the team — the ACTUAL mechanism (do not skip)

Both roles are real **teammates** — own context window, addressable via `SendMessage` — not one-shot subagents and not `dex` events. **The exact spawn mechanism depends on the harness; detect which one you're in FIRST, because the wrong assumption is what silently downgrades you to working solo.**

**Step 0 — detect the harness (one ToolSearch).** Search for `TeamCreate`. Two cases:

- **`TeamCreate` exists** → *explicit-team harness*. Stand the team up in two calls: (1) `TeamCreate(team_name="specdex-<spec-name>", description="<feature>")` once at Build entry, then (2) spawn each teammate INTO it by passing `team_name="specdex-<spec-name>"` on every `Agent` spawn. Here a real teammate's spawn result shows `agentId: <name>@specdex-<spec-name>` + *"will receive instructions via mailbox"*; a bare UUID means you omitted `team_name` — re-spawn.
- **`TeamCreate` is absent** (ToolSearch finds none, and `Agent`'s `team_name` param reads *"Deprecated; ignored — single implicit team"*) → *implicit-team harness* (the current default). **There is no TeamCreate step and there is nothing to "fix" — skip it.** The session already has one implicit team. You make teammates real simply by spawning **named, backgrounded** agents:

  ```
  Agent(name="coder",    subagent_type="dex-coder",    run_in_background=true, prompt=<brief>)
  Agent(name="reviewer", subagent_type="dex-reviewer", run_in_background=true, prompt=<brief>)
  ```

  `SendMessage` is **theirs by virtue of the agent type** — `dex-coder` and `dex-reviewer` both declare `SendMessage` in their own tool lists, so they can message each other and ping you (`SendMessage(to:"main")`) regardless of any team-creation call. `team_name` is accepted-but-ignored; passing it is harmless, relying on it as the "make-real" step is the bug. Address a live teammate by its **name**: `SendMessage(to:"coder", …)`.

**Verify you actually got a teammate — behaviorally, not by signature.** In the implicit-team harness a backgrounded spawn returning a bare UUID `agentId` + *"you will be notified when it completes"* is the **normal, correct result** — NOT the solo-fallback alarm it is in the explicit-team harness. Confirm the teammate is real by *using the channel* — and make that deterministic: the FIRST line of every spawn prompt orders an immediate `SendMessage(to:"main", "<role> alive")` ACK before any other work. No ACK within ~2 minutes = a dead spawn (they die silently: the spawn result looks healthy, `SendMessage` to the name reports "sent" into the void, and no completion notification ever fires — verified on this machine 2026-08-04). Respawn once; if named spawns keep dying, fall back to unnamed backgrounded agents addressed by their returned agentId, with the lead relaying coder⇄reviewer traffic. Never trust SendMessage's "sent" status as liveness. The real solo-fallback tell is universal and behavioral: **if you find yourself implementing a story's code yourself instead of through the `coder` teammate, you skipped the spawn** — stop and spawn it.

**Per-story names collide with shutdown.** You reuse the names `coder`/`reviewer` every story, but if the prior story's teammate is still terminating when you spawn the next pair, the system auto-suffixes the new one (`reviewer-2`, …). **Read the actual name from the spawn result and brief the coder with it** (e.g. "your reviewer is `reviewer-2`"). A stale name makes the coder's peer-ping land on a dead teammate, so the lead confirms the pair can reach each other — but **the lead never carries shas or findings itself.** A sha in flight is stale by the time it is read; the reviewer resolves HEAD for itself (see the review loop).

> **Launching a teammate ≠ `dex agent spawn`.** Launching creates a working Claude instance. `dex agent spawn coder|reviewer` is **only an event record** for the fleet view / audit trail — it launches nothing. Always launch the teammate FIRST, then `dex agent spawn …` to record it. If you're implementing a story yourself instead of through a `coder` teammate, you skipped the launch — stop and spawn it. (This is the single most common failure of this loop.)

**Permissions are inherited, not per-teammate.** Teammates start with **the lead's** permission mode (fixed at spawn). So the loop requires the **lead** to run in bypass (`claude --dangerously-skip-permissions`, which the resume command already uses); every teammate then inherits it. If a first-launch approval prompt appears, dismiss it. **Preconditions apply only to the explicit-team harness:** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and Claude Code ≥ 2.1.32 (agent teams are experimental and OFF by default there). In the implicit-team harness neither is needed — named backgrounded `Agent` spawns are the baseline capability. In *either* case the universal check is behavioral: if a spawn produces no teammate you can `SendMessage`, or you catch yourself coding a story by hand, you're in solo-fallback — surface it, don't quietly work alone.

**MANDATORY — every teammate enters the worktree first.** Spawned teammates are *separate* sessions that start at the repo root (the MAIN checkout), not your worktree. Every spawn prompt MUST carry the absolute worktree path and this rule:

> "Your worktree is `<absolute-worktree-path>`. Your session starts at the repo root, NOT there — so **as your FIRST action run `EnterWorktree(path="<absolute-worktree-path>")`** to switch your session into it. After that, bare `git` and relative paths resolve to your branch; confirm with `git status` that you're on `<branch-name>` before you start (the lead puts the real branch in your prompt — it is `specdex-<spec-name>` for a fresh worktree, but a run that reused an existing worktree has that worktree's own branch name; the lead reads it from `state.json`). If the branch does not match, STOP and tell the lead — never `git checkout` or `git branch` your way out of it in a shared worktree. Any sub-agent you spawn also starts at the root — give it the same path and tell it to `EnterWorktree(path=…)` first too. (`git -C <absolute-worktree-path> …` also works from anywhere if you need to be explicit.)"

**Each spawn prompt also sets the teammate's `dex` identity — by flag, never by export.** Teammates are *separate* sessions and do NOT inherit your shell, so every `dex` call they make (`dex test`, `dex review`, `dex note`) must carry its identity explicitly:

```bash
dex -s <project-name>/<spec-name> --actor coder <verb> ...    # or --actor reviewer
```

Do **not** rely on `export DEX_SPEC` / `DEX_ACTOR`: teammate shells do not persist environment between commands, and some repos' command verifiers reject `VAR=value dex ...` prefixes outright. Either way the events vanish silently — and a spec with no events is invisible to `resume`, the fleet view, and `dex story next`. Put the exact flagged form in each spawn brief.

**Communication — two planes.** Both teammates have `SendMessage` (full mesh): use it to cut roundtrips (reviewer messages the coder findings directly, no lead relay) — that's the fast lane. The **event log is the visibility plane**: every consequential message also records a matching `dex` event. Peers coordinate fix-rounds directly; **only the lead** decides PASS→ship, max-rounds→escalate, blocked→DM.

**One writer per worktree at any moment** — the coder, or a sub-agent it explicitly handed a disjoint file list, never both. **A completed sub-agent is done:** its final report is the whole result, and messaging it again reloads its entire context to restate what it already said. Never resume a completed agent for status — status lives in the tree (`git status`, `git log`) and in its report. Message a *running* agent only to change its course.

## Agent topology — which shape for which work

Three shapes exist; pick by what the work must remember and what it may touch.

| Shape | Use when | Never |
|---|---|---|
| **Named persistent teammate** (the standing coder/reviewer) | the role accumulates judgment across serial units of work in one tree — standards, prior findings, the story in flight | two of them writing to one worktree |
| **Fresh agent** (`Explore` / `general-purpose` / a custom type) | the task is self-contained given `context.md` plus an explicit brief — scouting, verification, a mechanical sweep, a consult on a different model | resumed for a second task; briefed by pointing at "what I said above" |
| **Fork** (`subagent_type: "fork"`) | — see below; in practice, don't | writing, messaging, being resumed, or needing a different model |

**Default to fresh.** `context.md` exists so a fresh agent orients in one read. If a brief would need more than the map plus a paragraph, improve `context.md` — do not reach for a fork to avoid writing the brief.

**Do not use `fork` for teammate-spawned work.** A fork inherits the parent's *entire* context — including the parent's identity and the lead's brief — and will conclude it *is* the parent and start acting as it, on the file plane *and* the message plane. It also costs the parent's whole context on every spawn and every resume, and it silently ignores `model` overrides, so it can never serve as a stronger-model consult. Its one theoretical niche (a critique with the parent's full reasoning context) is weak precisely because it shares the parent's blind spots: wrong claims get caught by *independent* evidence — a fresh grep, a runtime probe — never by re-reading the same context harder.

**Persistence boundaries.** Never replace an agent mid-story — in-flight state (open findings, a half-diagnosed failure) lives nowhere else. Recycle at story boundaries when context bloats; recycle both halves of the pair together at epic boundaries always. **Recycle ritual:** before shutdown, a retiring teammate appends its durable lessons — review checks it adopted, conventions it learned, traps it hit — to `context.md`'s Conventions/Decisions, so judgment survives the recycle the way facts already do.

## The per-epic cycle (the standing coder⇄reviewer pair)

A feature is built in **epics** (default: one epic = the whole feature; see *Epics*). Within an epic the **same** coder+reviewer pair works the stories **one at a time** — each its own commit + its own review gate. The pair is launched ONCE per epic and **persists across the epic's stories** (no teardown/respawn between them). Only the lead ends a story or an epic.

```
LEAD      ─ once per EPIC: launch the standing coder + reviewer (they read context.md)
            then, for EACH story in the epic, brief the SAME standing coder on THAT story
CODER     ─ implement (TDD) → commit feat(<spec>/<id>) → append a context.md delta
            └ ping "green @ <sha>, tests P/F"   →  lead + reviewer
REVIEWER  ─ review THIS story's diff + run the tests
            └ ping a VERDICT                     →  lead + coder
                 ├ PASS → LEAD marks `dex story done` → brief SAME pair on next story
                 └ FAIL → CODER fix → commit fix(<spec>/<id>) → ping again → reviewer re-reviews
                          (≤ 3 review rounds; still failing → LEAD blocks + stops)
LEAD      ─ at the epic's last story (or on context bloat): recycle the pair → next epic
```

**The review loop (mesh, ≤ 3 rounds).** The coder and reviewer both stay alive across this story's rounds; the lead watches the `dex review` verdicts and is the only one who ends the loop. Each **round N** (1, 2, 3):

- **(a) Coder → lead + reviewer.** Once the round's commit has landed (`feat(<spec>/<id>)` on round 1, `fix(<spec>/<id>)` after — confirm with `git -C <worktree> log --oneline -1`), `SendMessage` "`<id>` green @ `<sha>`, tests P/F" and record `dex test --passed … --failed …`. The coder does **not** emit `dex story done`. **One commit per round:** after sending the green ping the coder does not touch the worktree — no commits, no edits, no test runs — until the round's verdict arrives. The ping hands the tree to the reviewer; the verdict hands it back. A fix that occurs to the coder mid-round waits.
- **(b) Reviewer reviews round N.** **First runs `git -C <worktree> log --oneline -1` itself — the sha it reviews is HEAD, never one taken from a message.** If HEAD differs from the pinged sha, it reviews HEAD and notes the drift. Reads that commit + the touched files & their callers, runs the story's declared gate, writes `~/.spec/<project>/<spec>/review-<id>-<N>.md` (first line `VERDICT: PASS | PASS WITH NOTES | FAIL`, second line `Reviewed at HEAD <sha>`, then one `[BLOCKER|ISSUE|NIT] file:line — problem — fix` per finding), records `dex review --round <N> --verdict …`, and `SendMessage`s the verdict to **both** the lead and the coder. A verdict whose recorded sha is no longer HEAD when the lead reads it is **void** — no round is consumed and the reviewer re-reviews at the new HEAD. Void rounds do not count against the ceiling, but more than two on one story is a discipline failure: the lead stops and fixes the cause rather than looping.
  **Re-review rounds are delta-only.** Round 1 is the full audit. Round N>1 verifies each open finding against the fix commits' diffs, plus anything those diffs touch — it does not re-audit the story's full state.
- **(c) Branch on the verdict** (see *Escalation & severity* for what each severity means):
  - **PASS**, or **PASS WITH NOTES whose remaining items are only NITs** → story complete; the lead marks it done.
  - **FAIL**, or **PASS WITH NOTES with any BLOCKER/ISSUE** → the coder (already holding round N's findings) fixes, re-runs the affected tests, commits `fix(<spec>/<id>): <what>`, and loops to round N+1. Peer-to-peer — no lead relay.
- **(d) Ceiling.** ≤ **3 verdicts** (≤ 2 coder fix-iterations). If round 3 still isn't a pass, the lead stops: block + notify + halt. Earlier passed stories are already committed, so resume restarts from this one.

**On a passing verdict the LEAD marks completion** (only the lead ends a story): confirm the passing `dex review` landed, emit `dex story done <id> --commit <sha>` (head sha — the single completion signal, so the fleet view and `dex story next` advance only after review passed), then **brief the SAME standing pair on the next story** (`dex story next`) — do NOT shut them down between stories. Shut the pair down (a shutdown request to each → then `dex agent idle coder` / `dex agent idle reviewer`) only at the **epic boundary**, or to **recycle on context bloat** (then launch a fresh pair, which reloads `context.md`).

**The brief is frozen while a round is in flight.** After the coder ACKs a story brief, the lead sends no new constraints until a round boundary (the green ping, or a verdict). A constraint that cannot wait — it would void work in progress at a cost greater than the wait — goes as a single message whose first word is **STOP**; the coder ACKs before touching another file. Every late constraint gets a logbook line stating why it missed the brief. Anything that changes what the coder will *write* — names, numbers, target paths — is verified **before** the brief goes out: identifier-claim checks are plan-time work, not build-time.

**Coder brief** (the epic's standing coder gets the worktree rule above once at launch; for each story the lead hands it the story's id/name/AC/files plus this standing brief):
> "First, **read `~/.spec/<project>/<spec>/context.md`** for the map — it tells you where things are and the load-bearing facts; still open the real file before you edit it (the map orients, it doesn't replace reading). Implement ONLY the one Build Story I give you, TDD (RED → GREEN), parallelizing independent chunks via sub-agents. Follow the **Escalation & severity** rules: make reversible (two-way-door) calls yourself and `dex note` your reasoning — don't stall on me for those; but `SendMessage` me any genuine one-way-door decision (irreversible API/schema/data-format/security choice) before you bake it in. Run the story's declared gate — never the project's full unfiltered suite. Send me one line whenever you start anything that will take more than a few minutes (a build, a suite run), saying what it is: silence during a long step is indistinguishable from a dead session and forces me to come looking. Commit just this story — `git -C <worktree> commit` message `feat(<spec>/<id>): <name>`. `SendMessage` me (the lead) AND the reviewer a short report (what you built, exact test commands + pass/fail counts, the commit sha, deviations, unverified items), append it to `~/.spec/<project>/<spec>/coder-report.md`, and **append a one-line delta `- <id>: <what changed, by symbol>` to the *Story deltas* section of `~/.spec/<project>/<spec>/context.md`** so the next teammate sees it. Record `dex test --passed … --failed …` (do NOT emit `dex story done` — completion is the lead's after review passes). Then STAY ALIVE: the reviewer may `SendMessage` findings — fix, re-run tests, commit `fix(<spec>/<id>): <what>`, message both, stay alive. After a story passes I'll hand you the next one — keep your context; don't shut down. Do NOT emit `dex review` or `dex story done`. Shut down only when I tell you the epic is done."

## Stories

Stories are the unit of the build loop and what makes a run **resumable** — each lands as its own commit, so a crashed run picks up at the next un-built one instead of re-running the whole feature in a rotting context.

- **Id `S1..SN`** — the stable key, kept for commits (`feat(<spec>/<id>)`) and resume. A short imperative **name** (≤ ~6 words) doubles as the commit subject; a **one-line summary** describes what it does. (Authoring format lives in *Plan → Build stories*.)
- **Completion = review-passed**, marked by the lead (`dex story done`) — never the coder, never at first commit.
- **Authored once** at plan time and static; live status lives in git + `dex story`, not in the spec.md list.
- **Resume** keys off git history (`feat(<spec>/<id>)` commits exist) and `dex story next` (first non-Done).

## Epics — the teammate-lifecycle unit

Stories are the unit of *work* (commit, AC, resume); an **epic** is the unit of *teammate lifecycle*. An epic is a batch of related stories worked by one standing coder+reviewer pair, so a pair fits **many stories** instead of being torn down and respawned each one (the spawn/teardown + re-orientation churn was the dominant cost on small features).

- **Default: the whole feature is ONE epic** — one pair start-to-finish, with the per-story review gate inside. Don't add epics for a normal-sized feature.
- **Split into multiple epics only for a large feature** (a clean seam like backend/frontend, or more than ~6 stories): group the stories at plan time, each epic gets its own pair. A natural split is also wherever a single pair's context would otherwise bloat.
- **Recycle = teardown + fresh pair** at an epic boundary, or mid-epic if a pair's context is bloating. The fresh pair reloads `context.md`, so recycling is cheap.
- Epics change **nothing** about stories: same ids, same `feat(<spec>/<id>)` commits, same resume keying, same per-story review gate. Stories stay still.

## The shared context doc (`context.md`)

`~/.spec/<project>/<spec>/context.md` is the feature's **onboarding doc** — what a fresh teammate reads instead of cold-reading the codebase. It exists so the map is written ONCE rather than re-explained in every spawn brief.

- **Written once, at Plan, by the librarian** (see *Roles*): a curated digest — **Map** (subsystem boundaries + load-bearing facts/invariants), **Key files** (by *symbol*, never line numbers — they rot within a story), **Conventions** (test commands, style), **Decisions**, and an initially-empty **Story deltas** section.
- **Read on every teammate launch.** Each spawn brief opens with "read `context.md` first", so the brief shrinks to the story-specific 3–5 lines. It replaces *discovery*, not *verification*: a teammate still opens the real file before editing it.
- **Kept current by one-line deltas** — the coder appends `- <id>: <what changed, by symbol>` to *Story deltas* when a story lands (no agent re-run). So the next teammate, any recycled/fresh pair, the final reviewer, and resume all see current status.
- It is **not** the logbook. `logbook.md` is the chronological *why*-trail (decisions + reversibility); `context.md` is the *where/what* map. Don't merge them. It pays off most when a *fresh* teammate appears: epic recycle, the final integration reviewer, resume-after-crash.

## Escalation & severity

The run exists to *finish*. **Default to motion:** the lead and every teammate act on their own judgment — recommended practice, reasonable assumptions, the obvious path — instead of pausing. Don't interrupt the user for anything you can decide.

**The one test for stopping a decision is reversibility** — *how hard is it to change after the feature ships?*

- **Two-way door** — cheap to reverse (naming, internal structure, a swappable library, a flippable default). **Decide it yourself and log it. Never stop for these.**
- **One-way door** — expensive/impossible to undo once shipped (public API/SDK shape, DB schema/migration, persisted data format others depend on, irreversible delete/overwrite, a security boundary, any locked-in external contract). **The only class that stops the user:** the lead notifies with the choice + a recommendation, and waits.

**Log every consequential decision** — the trade for not asking. Lead → `logbook.md`; teammates → `dex note` + their report. Each entry: **what** / **why** / **how** / **reversibility** (`cheap` / `moderate` / `expensive`). If that last field comes out `expensive`, that's the tell it was a one-way door — stop and ask.

**Review finding severity** (drives the per-story review loop's branch):

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
| zellij | `zellij attach spec-<spec-name> 2>/dev/null \|\| { zellij attach -b -c spec-<spec-name> && zellij --session spec-<spec-name> run -- claude --continue --dangerously-skip-permissions && zellij attach spec-<spec-name>; }` | `Ctrl+O, D` |
| tmux | `tmux new-session -A -s spec-<spec-name>` | `Ctrl+B, D` |

If `$ZELLIJ_SESSION_NAME` is unset (not inside zellij), warn and wait for the user to confirm continue-anyway or restart inside a multiplexer:

> You're not inside zellij. If you close this terminal, the autonomous loop dies. Start one and re-run `/specdex` inside it — `zellij attach spec-<spec-name>` (detach `Ctrl+O, D`).

## 1. Names + ambient spec

- `<spec-name>`: a short kebab-case slug of the feature (e.g. `auth-middleware`).
- `<project-name>`: the basename of the current project dir (e.g. `anyformat-backend`).

Send the start notice:

```bash
notify ":rocket: *[<spec name>]* Spec started — setting up workspace"
```

**Your own `dex` calls carry their identity as flags too** — `dex -s <project-name>/<spec-name> --actor lead <verb> ...`. Exports do not survive between your Bash invocations any more than they do between a teammate's; a call with no target records nowhere and fails silently.

## 2. Create spec directory

All specs live at `~/.spec/<project-name>/<spec-name>/` (the single cross-project registry). Holds `spec.md` (approved plan), `context.md` (shared onboarding map, written by the librarian at Plan — see *The shared context doc*), `logbook.md` (timeline), `env.md` (ports/project record).

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

**Project bring-up first.** If the repo's CLAUDE.md defines a fresh-checkout bring-up, run it in the worktree now (anyformat-backend: `make setup` then `uv run af worktree` — seeds `.env` and isolates ports/compose project; skipping it collides with the main dev stack).

Then, if `.spec-env` exists in the project root and bring-up didn't already seed a `.env`, copy it silently into the worktree as `.env`. If neither produced one, warn once and continue — don't block.

```bash
cp <original-project-root>/.spec-env .env 2>/dev/null
```

## 5. Ports

If the spec runs local services, allocate ports: `eval "$(dex ports alloc)"`. (A no-op without `[[ports]]` in `.dex.toml` — fine when project bring-up already isolated ports, e.g. `uv run af worktree`.) See **`reference/ports.md`** for the offset algorithm and the `.env`/`env.md` templates. (Record what you allocate — Complete's docker shutdown frees exactly these.)

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
7. **Spawn the librarian** (an `Explore` agent) to write `~/.spec/<project>/<spec>/context.md` from the codebase + the approved plan — the map every teammate will load (see *The shared context doc*). You already seeded most of this during step 2's exploration; the librarian curates it into the doc (Map / Key files by symbol / Conventions / Decisions / empty Story deltas) so it isn't re-derived per spawn.
8. Log approval in the logbook.

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
- **The spec is self-contained** — every measurement, number, or claim a story will assert appears inline in `spec.md` or `context.md` with its method and fixture. A link a teammate cannot fetch (a claude.ai artifact, a private dashboard, a session scratchpad) is not evidence: inline the content or drop the claim.

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
- **Group into epics only if the feature is large** (see *Epics*): annotate the list with `### Epic A — <name>` / `### Epic B — <name>` headings. Default is a single implicit epic — no annotation, one standing pair for the whole feature.
- **Tag each story's review depth.** `gate: full` (the default — it changes runtime behaviour or a contract: code, schema, pricing, config the product reads) or `gate: light` (docs/ADRs/comments — the reviewer verifies claims, links and naming in one pass, runs no tests, and folds NITs without a re-round). The rule is behaviour-and-contract change, **not file count**: a one-line pricing table is `full` because a wrong number is a billing bug; a large ADR set is `light`. Every story still gets a review — on the smallest story of a real run, round 1 caught two defects that would have misdirected later work.

**Gates are declared per story.** For each story the Verification section names the narrowest check that catches *that story's* failure mode. A per-story gate never calls live paid services and never runs the project's unfiltered full suite; the unfiltered suite runs exactly twice — once at the final integration review, once in CI on the PR. **A gate's cost is itself reviewable:** if a per-story gate takes more than a few minutes or spends money, the coder flags it (`dex note`) instead of repeating it. The loop's most-repeated action must be its cheapest, and a plan that inherits an unscoped test target from the repo will pay that cost on every story without ever questioning it.

**Only after the user explicitly approves the plan, proceed to Build.**

# Build

The autonomous heart — runs the per-epic cycle (*The loop & rules → The per-epic cycle*).

**Enter.** `dex phase build`. **Stand up the team per *Launching the team* (Step 0 first)** — in the explicit-team harness that's `TeamCreate(team_name="specdex-<spec-name>")` once and confirm it returned a team (not a no-op); in the implicit-team harness there's no TeamCreate step, you go straight to spawning the named backgrounded pair. The epic's standing coder + reviewer come up either way. **Register the stories** (`dex story add --id <id> --title "<name>" --summary "<summary>"` for each `## Build Stories` entry). Then notify build-started and tell the user they can detach:

```
notify ":hammer_and_wrench: *[<spec name>]* Build started — standing-pair loop. You can detach now (Ctrl+O, D). Next DM on review FAILs, blocks, or the final-review pass."
```

**Run the loop — per epic, per story.** For each **epic** (default: one epic = the whole feature; see *Epics*):

1. **Launch the epic's standing pair ONCE** — a `coder` AND a `reviewer` INTO the team via `team_name="specdex-<spec-name>"` (agent types `dex-coder` / `dex-reviewer` — see *Launching the team*). Brief each with the worktree rule + "read `context.md` first" + its standing role brief. Record `dex agent spawn coder` / `dex agent spawn reviewer`.
2. **Loop the epic's stories** via `dex story next` (until the epic's stories are done):
   - `dex story start <id>` + `dex beat` (heartbeat — emit one each iteration).
   - **Brief the SAME standing coder** on THIS story (id/name/AC/files) — do NOT respawn between stories.
   - Run the **review loop** for the story (the (a)–(d) protocol in *The per-epic cycle*); the standing reviewer reviews this story's diff.
   - On a passing verdict the **lead** marks `dex story done` and briefs the SAME pair on the next story.
   - If a pair's context bloats mid-epic, recycle it (teardown → fresh pair, which reloads `context.md`).
3. **At the epic boundary**, retire the pair (shutdown request → `dex agent idle coder` / `dex agent idle reviewer`) and move to the next epic (its own fresh pair). For a single-epic feature, this teardown coincides with all stories being done.

## Final integration review

When `dex story next` is empty (every story built + reviewed), `dex phase review` and **spawn a fresh `reviewer`** into the team for ONE light pass for **cross-story coherence** — do the stories compose, are there integration gaps the per-story diffs couldn't see? It does NOT re-review each diff; it reads the composed code, not any per-story memory (which is why a fresh instance is the right call). Same `dex review` mechanism, written to `review-final.md`; same 3-round ceiling — route fixes to a **fresh coder** (also spawned into the team), committing `fix(<spec>/integration): <what>`.

**On PASS → Ship**, in order: `notify ":tada: *[<spec name>]* All stories built + reviewed — shipping PR"` → shut the final reviewer (and any integration coder) down — shutdown request → `dex agent idle reviewer` — **but leave the team itself up** for Ship/Verify (CI/bot fixes may need a fresh coder; `TeamDelete` happens at Acceptance) → log → proceed to Ship.

**Blocked** (a per-story 3-round failure OR a final-review block):
```
notify ":rotating_light: *[<spec name>]* Blocked — <story <id> | final review> failed after 3 rounds\n>*Phase:* <build | review>\n>*Reason:* <unresolved findings>\n>*Resume:* `zellij attach / tmux attach <session-name>`"
```
Then `dex block "<why>"`, log, and stop.

# Ship

On entry, `dex phase ship`. The build loop already committed each story, so the branch *is* the per-story commits and the tree is clean. Use the `/pr` skill to:

1. Push the branch (its commit step is a no-op when nothing is staged). If `/pr` finds uncommitted changes, treat it as a bug — investigate before pushing.
2. Create a PR targeting `dev`.

**Scope `$SHIP_ACTION` to push + PR — state these overrides when you invoke it.** A general-purpose ship skill does more than specdex wants, and each extra step is actively harmful here:

- **Ticket lookup:** attach a tracker ticket only if `spec.md` names one; otherwise skip. A ticket search that ends in "pick one, create one, or skip" is an interactive question in the middle of the autonomous phase — after the user was told they could detach. That is a hard stop, not a degradation.
- **No rebase / no history rewrite.** A rebase (or any `--force-with-lease` push) invalidates every sha the run recorded: `dex story done --commit`, each review report's `Reviewed at HEAD`, and the logbook. The audit trail dangles and resume loses its anchors. If the branch is behind the base, let the PR's own merge check say so.
- **No test run.** The per-story gates and the final integration review already ran; the unfiltered suite runs exactly twice by design (final review + CI). A ship-time run is a third, at full cost and for no new information.
- **No blanket hygiene autofix.** A formatter sweeping files this spec never touched is unreviewed churn, and in repos whose lint config diverges from the formatter's output it corrupts untouched files. Anything larger than formatting on files this spec changed goes back through the reviewer — the integration review already passed, and a post-review mutation invalidates it.

**Transition → Verify**, in order:
1. `dex pr --number <N> --url <PR URL>` (records the spec↔PR link in `state.pr`).
2. `notify ":link: *[<spec name>]* PR created — <PR URL>, watching CI"`.
3. Log, then proceed to Verify.

# Verify — CI + bot review

Two parts: **CI watch** then **bot review**. On entry `dex phase verify`; `dex beat` each poll cycle; record outcomes with `dex gate --provider ci|review …`.

## CI watch

Poll the PR head until green or intentionally ignored — via `ScheduleWakeup`, delay matched to how long the CI run actually takes (e.g. `delaySeconds: 480` for an ~8-min pipeline); never tight-loop.

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

Wait for the bot to comment, read its findings, then **fix and re-trigger**. Record each round `dex gate --provider review --result <success|failure> --score <0-5>`.

**Read the findings the way `$REVIEW_REACTOR` says to, not with `gh pr view --comments`** — that dumps every comment in history as fragile tab-separated text and usually serves stale data. Use the API form the reactor documents (`gh api "/repos/<owner>/<repo>/issues/<number>/comments" --paginate` for the summary, `/pulls/<number>/comments` for inline threads, filtered with `contains(...)` because bot logins carry a `[bot]` suffix that breaks exact matches). Where this skill and the reactor skill disagree about mechanics, **the reactor is authoritative** — it is the one maintained against the bot's actual behaviour.

**Threshold and ceiling.** Define the pass threshold once, here, and read it from here — not from the diagram: pass = the configured score with no open blocker-level findings. And give this loop the same discipline as the build gate: **≤ 3 bot rounds.** If the score plateaus — the same score twice running with only style-level findings left — stop looping: notify the user with the PR link and the standing findings and let them merge over it. The bot is advisory past that point, and an unbounded loop is two DMs a round forever.

- **The lead handles bot rounds directly** for small/mechanical findings (the bot hands you the exact fix) — edit, push, reply, re-trigger, no coder spawn. This is the fast path for the majority of findings; by Verify the build is done, so the lead's context isn't being preserved for fresh story work.
- **Spawn a fresh coder ONLY for a story-sized finding** — a real defect needing design judgment or a multi-file change (a behavior bug, a new abstraction, a security/data-shape issue). Brief it with the finding + "read `context.md` first".
- Use `$REVIEW_REACTOR` to reply to every thread + push the fix; **re-trigger with a PR comment containing `@greptile review`** — an `@greptile-apps` mention does NOT trigger a re-review, and there is NO auto-re-review on push. Then poll for a NEW summary comment whose *Last reviewed commit* matches your pushed sha (the count of Greptile summary comments increments) before reading the new score.

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
3. Tear down the build team: shut down any teammate still alive (shutdown request). In the explicit-team harness also `TeamDelete` (removes `~/.claude/teams/specdex-<spec-name>/`); in the implicit-team harness there's no team object to delete — shutting the teammates down is the whole teardown.
4. `notify ":broom: *[<spec name>]* Accepted — docker down, ports freed. PR ready to merge."`

The worktree + branch stay (merging is manual) — no worktree cleanup.

# Modes

Default `/specdex <feature>` runs the whole loop above. `--auto-approve <plan-path>` is a modifier (see *Plan*). Two non-default modes:

## collaborate (`/specdex collaborate <feature>`)

A **human-driven** session you still want visible in the fleet — you and the user drive the work directly, no coder/reviewer team, no autonomous ship/CI loop.

1. Lighter setup: a new worktree **or** the current checkout. Register with the collaborative flag: `dex init --branch <branch> --worktree "$(pwd)" --collaborative`.
2. Passing `-s <project>/<spec-name> --actor lead` on every call, emit phase events as work actually moves (`dex phase plan` → `dex phase build` → …) and `dex beat` at checkpoints. Optionally `dex agent spawn lead`. Do not rely on an exported `DEX_SPEC`: it does not survive between Bash invocations, so every event after `init` would silently record nowhere — and the spec would go permanently stale in the fleet, which is the one thing collaborate mode exists to provide.
3. Save the design doc to `~/.spec/<project>/<spec>/spec.md`.
4. No team review/PR automation — the human decides when to ship; if a PR opens, record it (`dex pr …`).
5. A natural stopping point: `dex phase complete`.

## resume (`/specdex resume`)

Re-attach to the most recent non-terminal spec for this project and continue from **durable state, not a remembered context**. Read the phase (`dex ls` / `state.json`), then:

- **`build`:** **position comes from events plus the tree, not from git alone.** `dex story ls` is the truth for done/active/pending (`dex story next` = first non-done). Then reconcile against the tree two ways *before* briefing anyone:

  **(1) A story with a `feat(<spec>/<id>)` commit that is not `done` crashed mid-review.** A `--grep "feat(<spec>/"` sweep counts it as built — wrong exactly when a crash matters, because a story can be committed *and* reopened. Its open findings are in the highest-numbered `review-<id>-<N>.md` (the next round is N+1), and fix commits may already sit at HEAD awaiting a verdict. **Resume such a story at the REVIEW step, not at implementation** — brief the fresh reviewer with the open findings file and the current HEAD.

  **(2) `git status` — uncommitted work is the dead coder's half-done story.** Read it against that story's acceptance criteria, then brief the fresh coder to *finish and commit* it, or park it (`git stash` plus a logbook line saying what and why). Never let a fresh coder start over on top of files it did not write, and never discard them silently.

  Then ensure the team exists per *Launching the team* (Step 0 detect) — explicit-team harness: `TeamCreate(team_name="specdex-<spec-name>")` if `~/.claude/teams/specdex-<spec-name>/` is absent, else reuse it; implicit-team harness: no check needed — and **launch a fresh standing pair for the current epic**. The pair reads `context.md` to re-orient, but **open review findings live in `review-<id>-<N>.md`, not in `context.md`** — the resume brief hands those over explicitly. Durable state plus the map, not remembered context, is the whole point.

  Also reconcile the agent records: `dex agent idle coder` / `dex agent idle reviewer` for any pair the crash left recorded as active, before spawning the replacements — otherwise the fleet shows a dead pair alive indefinitely.
- **`review` / `ship` / `verify`:** re-enter that phase (ensure the team exists per the `build` rule and re-spawn a reviewer into it if one is needed, re-poll CI/bot). Committed work + recorded gates are the truth.
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

The webhook lives in `~/code/dotfiles/apps/specdex/.env` (gitignored — its single home); the *Configuration* resolver reads it from there, and an explicit `DEX_NOTIFY_WEBHOOK` export overrides. Everywhere this skill writes `notify "<message>"`:

```bash
notify() {
  [ -z "$WEBHOOK" ] && return 0
  curl -fsS -X POST -H 'Content-Type: application/json' \
    -d "$(jq -n --arg t "$1" '{text:$t}')" "$WEBHOOK" >/dev/null || true
}
```

See **`reference/slack.md`** for the message format / emoji table.

# dex CLI — what & when

`dex` is the telemetry substrate (events → derived state the fleet + resume read). Every call carries `-s <project>/<spec-name> --actor <lead|coder|reviewer>` — the actor records WHO emitted it. Never exports; they do not survive between invocations. This whole section is **scoped and removable**: every `dex` call is a harmless no-op if the binary is absent, so dropping this table decouples the skill from the substrate. The table below is the *when*; for the complete spec of every verb, flag, and enum, see **`reference/dex-cli.md`**.

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
| Coder/reviewer launched·idle | `dex agent spawn coder --id <id>` / `dex agent spawn reviewer --id <id>` / `dex agent idle <role>` |
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
