---
name: slices
description: Plan, run, track and close a multi-slice change (an epic) with explicit goals and acceptance criteria per slice, a loop folder that survives sessions, parallel waves through the slices-wave workflow, and a retro that turns signals into rule changes. Use when work spans more than one slice, when the user says "slices", "plan this", "retoma", "cómo va", "qué falta", or asks to run slices in parallel.
---

# Slices

One epic = one loop folder: `~/.artifacts/<repo>/loops/<epic>/`. `<repo>` is the repository directory name; `<epic>` is a short kebab-case name.

| File | Holds | Changes |
|---|---|---|
| `plan.md` | goal, out of scope, locked decisions, code map, slices with acceptance criteria and waves | rarely; the user approves it |
| `loop.md` | each slice's status, evidence, PR link, workflow run id | at every step |
| `logbook.md` | dated decisions and events, one line each | append only |
| `signals.md` | friction the agents hit, one line each | append only, consumed by the retro |

Only the main agent writes these files. Subagents report; the main agent copies.

Templates: [`templates/`](templates/). Copy them; do not invent another shape.

## start `<epic>`

1. Create the folder and copy the four templates into it.
2. Send `explorer` to map the code the epic touches. Put its map in `plan.md` under "Code map": key files by symbol, never by line number.
3. Write `plan.md`: the goal, out of scope, locked decisions, and every slice with its goal, out-of-scope list, acceptance criteria (a command and its expected result), the files or areas it touches, and the slices it depends on.
4. Group the slices into waves: a wave holds slices with no dependency between them. Mark two slices in one wave that touch the same files with `isolation: worktree`.
5. Show the user the slice table and the waves, and wait for approval. Approval of the plan is approval to run its waves and open its PRs; nothing else is.
6. Copy the slice list into `loop.md` with status `todo`. Log the approval in `logbook.md`.

## status (also on "retoma", "cómo va", "qué falta")

1. Read `loop.md`, then verify each slice that is past `coding` against its source: the PR state, CI, the review bot's latest verdict on the head commit. Never answer from memory.
2. Update `loop.md` with what changed.
3. Answer with one table: slice | goal in plain words | status | evidence or blocker | PR link. Then the next step.

## run `<wave>`

Run one slice inline (coder, then reviewer) when the wave has one slice. Run a wave of two or more through the saved workflow:

```
Workflow({ name: "slices-wave", args: { epic, repo_path, wave, slices: [ { id, goal, out_of_scope, acceptance: [{id, command, expected}], touches, isolation } ] } })
```

- Two slices that run in parallel always run through `slices-wave`, even when the plan put them in separate waves. Never hand-spawn parallel coders, and never fold a slice's own review into the PR review.
- Pass the slice blocks from `plan.md` verbatim. Record the run id in `loop.md` next to the wave; resume a broken wave with `resumeFromRunId`.
- If the named workflow is not found, pass `scriptPath: "~/code/dotfiles/config/claude/workflows/slices-wave.js"` instead of `name`.
- When it returns, check each slice's evidence yourself before marking it `done`: the AC commands, the reviewer's verdict line. Copy every `signals` entry into `signals.md` with the slice id.
- A slice that ended with `Verdict: fix ...` after 3 rounds is `blocked`. Report it to the user with the open findings; do not start a fourth round on your own.

## retro

Run it as the last slice of every loop, and when the user asks.

1. Read `signals.md` and `logbook.md`.
2. Group the signals that repeat or that cost a round. Ignore one-offs with scope `slice`.
3. For each group, propose one concrete change: the file (a generic agent or `AGENTS.md`, a repo profile under `~/code/dotfiles/config/claude/profiles/<repo>/`, a skill, the workflow, or a memory fact), the exact line, and the evidence (which signals, how many times).
4. Show one table: what happened (count) | proposed line | file. Apply what the user approves, mark those signals `[used]`, and log the retro in `logbook.md`.
5. On the next loop, check whether the same signal came back. If it did, the rule did not work: say so in the next retro.
