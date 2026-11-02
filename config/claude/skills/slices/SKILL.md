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

## Decide or stop

Approval of the plan is a standing approval to decide inside it. When a decision is reversible and stays inside the plan's goal, out-of-scope list and locked decisions, take the recommended option and continue. Log it in `logbook.md` as `decided:` with the alternatives, the reason and how to revert it, and add a row to "Decided for you" in `loop.md`. The user can veto any row; a veto becomes a fix slice.

Add a slice the same way when it serves the approved goal and crosses no gate below. Mark it `added` in `loop.md`.

Stop and ask only at these gates:
- An approval boundary from CLAUDE.md: a dependency, a public API or contract, data deletion, security or permissions, production infrastructure, an external service.
- A slow or costly step: a benchmark, a full eval, a corpus rebuild, or any run expected to take more than 20 minutes or to hold up other slices. Stop before you launch it, with the estimated time, the cost, what it unblocks and a smaller alternative, such as a sample.
- A change to the goal, the out-of-scope list or a locked decision, or evidence that an acceptance criterion cannot be met as written.

## start `<epic>`

1. Create the folder and copy the four templates into it.
2. Send `explorer` to map the code the epic touches. Put its map in `plan.md` under "Code map": key files by symbol, never by line number.
3. Write `plan.md`: the goal, out of scope, locked decisions, and every slice with its goal, out-of-scope list, acceptance criteria (a command and its expected result), the files or areas it touches, and the slices it depends on.
   - Each acceptance criterion is the command that produces the result where it will run, against the real artifact, never against a constant from the code. A comparison uses a baseline measured the same day, not a historical number. A slice that adds telemetry has the signal visible in the environment's observability tool as its criterion.
   - A slice that changes a contract others consume (a route, a schema, a tool, a wire key, a file format) lists its consumers and every place the contract is written (docs, docstrings, schemas, generated clients), and updates them in the same slice. A consumer cannot sit in the out-of-scope list of the slice that changes its contract. The PR body carries a `Breaking change:` line.
4. Group the slices into waves: a wave holds slices with no dependency between them. Mark two slices in one wave that touch the same files with `isolation: worktree`.
5. Send `reviewer` the plan, not a diff, with two questions per slice: does a much simpler change reach the same goal, and does the slice fix the root cause of a need users have? Change the plan for each finding with a concrete case, and show the user the findings you rejected and why.
6. Rehearse the plan when it has three or more slices, or any acceptance criterion that runs a benchmark or an eval:
   - Run every acceptance criterion command now, on the base, where its slice will run it. Each one must run and fail for the expected reason, or print the baseline. A command that cannot run there (a missing stack, service, fixture or permission) changes the plan now, not mid-wave.
   - Send `explorer` once per slice for a pre-mortem: read the code the slice touches and list what would make its coder stop, such as an ambiguous contract, an unknown caller, a missing fixture or a choice between options. Settle each item in the plan, or turn it into a question for step 7.
   - Log the rehearsal result in `logbook.md`.
7. Show the user the slice table, the waves and every open question in one message, each question with its options and a recommendation, and wait for approval. Approval of the plan is approval to run its waves, open its PRs and decide inside the plan as "Decide or stop" says; nothing else is.
8. Copy the slice list into `loop.md` with status `todo`. Log the approval in `logbook.md`.

## status (also on "retoma", "cómo va", "qué falta")

1. Read `loop.md`, then run [`status.sh`](status.sh) `<loop dir>`: one line per PR linked in `loop.md` with its state, base, head, CI, review-bot score, open bot threads and mergeability. Never answer from memory, and never rebuild this with ad-hoc `gh` calls.
   - CI is green only when every expected check has completed and passed on the head SHA. A pending, queued or missing check is not green: right after a push, "no failing checks" and "nothing has run yet" look the same. The same bar applies before a slice is marked `done`.
   - For a failed check, fetch only that job's log to a scratchpad file and `grep` it for the failing test names; never read a whole CI log into context. A job killed by a timeout prints no per-test reason: check whether other branches fail the same tests in the same window before blaming the slice.
2. Update `loop.md` with what changed.
3. Answer with one table: slice | goal in plain words | status | evidence or blocker | PR link. Then the "Decided for you" rows added since the last status, and the next step.

## run `<wave>`

Run one slice inline (coder, then reviewer) when the wave has one slice. Run a wave of two or more through the saved workflow:

```
Workflow({ name: "slices-wave", args: { epic, repo_path, wave, slices: [ { id, goal, out_of_scope, acceptance: [{id, command, expected}], touches, isolation } ] } })
```

- Two slices that run in parallel always run through `slices-wave`, even when the plan put them in separate waves. Never hand-spawn parallel coders, and never fold a slice's own review into the PR review.
- Pass the slice blocks from `plan.md` verbatim. Record the run id in `loop.md` next to the wave; resume a broken wave with `resumeFromRunId`.
- From a session isolated in a worktree, do not launch `slices-wave` with `isolation: worktree`: the guard refuses git to the fix-round agents. Run the wave's slices serially in the session's worktree.
- If the named workflow is not found, pass `scriptPath: "~/code/dotfiles/config/claude/workflows/slices-wave.js"` instead of `name`.
- When it returns, check each slice's evidence yourself before marking it `done`: the AC commands, the reviewer's verdict line. Copy every `signals` entry into `signals.md` with the slice id, and every `follow_ups` entry (the P2 findings left on a slice that shipped) into the "Follow-ups" table of `loop.md`. A slice run inline does the same with its reviewer's P2 findings. Copy every `decisions` entry as "Decide or stop" says. A slice that returned `stopped` hit a gate: report the gate and the coder's reason to the user.
- A slice that ended with `Verdict: fix ...` after 3 rounds is `blocked`. Report it to the user with the open findings; do not start a fourth round on your own.
- Every defect a brief states carries its evidence: a `file:symbol` citation of the code as it is on the base today, or the output of a probe that reproduces it. A defect without one stays out of the brief. A probe against a live API builds its requests from the API's SDK or schema, never from guessed field names, and records the status and body of every non-200 response.
- Every coder and reviewer brief carries the worktree block: the absolute worktree path, that `uv sync --all-packages` and the `.env` copy are done there, one plain command per call, and multi-step scripts written as files in the scratchpad.
- Every slice that commits while another slice is active gets its own worktree, stacked or not. Two slices committing from one checkout clash on the index, on pre-commit stashes and on whole-tree hooks, and a broad `git add` sweeps up the other slice's files.
- The coder commits its work (a WIP commit is fine) before the review starts, and names the SHA, so the review reads a frozen commit. Drift checks that compare the working tree with the git index (`--check` modes, generated-client checks) pass once the regenerated files are staged; run them before the commit, not after. The reviewer reviews in a detached worktree at that SHA (`git worktree add --detach <path> <sha>`), never in a tree someone is still editing, and may mutate code there to prove a finding.
- Stacked slices become a GitHub stack: after their PRs exist, run `gh stack link --base <trunk> <bottom-pr> ... <top-pr>`. GitHub then rebases the upper PRs and retargets them when a lower one merges, and `gh stack merge <top-pr>` merges the whole stack atomically. If the repository has stacks disabled, the command says so: fall back to merging bottom-up and retargeting each child yourself.

## retro

Run it as the last slice of every loop, and when the user asks.

1. Read `signals.md`, `logbook.md` and the "Follow-ups" table of `loop.md`.
2. Group the signals that repeat or that cost a round. Ignore one-offs with scope `slice`. Count the findings a reviewer reported late (on code unchanged since an earlier round) as a reviewer signal. Count the vetoed "Decided for you" rows as signals against the decision rule.
3. Triage each group by where its fix lives:
   - **Loop**: how we work. A skill, a generic agent, the workflow, `AGENTS.md` or a memory fact, in `~/code/dotfiles`. Usually scope `tooling`.
   - **Project**: how this repository works. Its profile under `~/code/dotfiles/config/claude/profiles/<repo>/`, or its own rules, tests or CI through a PR in the repository. Usually scope `repo`.
   - **Backlog**: what the product needs. An issue, never a rule. Usually scope `product`.
4. For each group, propose one concrete change: the file or the issue, the exact line, and the evidence (which signals, how many times).
   - Write a loop line for the pattern, not for this epic: it must make sense to a slice of unrelated work in another repository. Name no module, route or format of this epic. If it only makes sense here, it is a project line.
   - Write every proposed line in English, whatever language the conversation uses.
5. Show one table per destination (loop, project, backlog): what happened (count) | proposed change | file or issue. Apply what the user approves, mark those signals `[used]`, and log the retro in `logbook.md`.
6. Show the follow-ups in a last table: finding | location | proposal (open an issue, or drop it and why). Open the issues the user approves and mark each row `issue <link>` or `dropped`.
7. On the next loop, check whether the same signal came back. If it did, the rule did not work: say so in the next retro.
