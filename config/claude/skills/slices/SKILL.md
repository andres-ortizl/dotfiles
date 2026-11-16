---
name: slices
description: Plan, run, track and close a multi-slice change (an epic) with explicit goals and acceptance criteria per slice, a loop folder that survives sessions, parallel waves through the slices-wave workflow, and a retro that turns signals into rule changes. Use when work spans more than one slice, when the user says "slices", "plan this", "retoma", "cómo va", "qué falta", "mergeado", or asks to run slices in parallel.
---

# Slices

One epic = one loop folder: `~/.artifacts/<repo>/loops/<epic>/`. `<repo>` is the repository directory name; `<epic>` is a short kebab-case name.

| File | Holds | Changes |
|---|---|---|
| `plan.md` | goal, out of scope, locked decisions, code map, slices with acceptance criteria and waves | rarely; the user approves it |
| `loop.md` | each slice's status, evidence, PR link, workflow run id | at every step |
| `logbook.md` | dated decisions and events, one line each | append only |
| `signals.md` | friction the agents hit, one line each | append only, consumed by the retro |

Only the main agent writes these files. Subagents report; the main agent copies. Set a table cell with [`loop-row.py`](loop-row.py) `<file> <section> <row key> <column> <value>`, never with a prefix match.

Templates: [`templates/`](templates/). Copy them; do not invent another shape.

## Packs

This file holds only what every slice needs. Everything else is a pack: a short file loaded only for the slices its trigger matches. Generic packs live in [`packs/`](packs/); packs for one repository live in its profile, `~/code/dotfiles/config/claude/profiles/<repo>/packs/`, indexed in that profile's `main.md`. Lessons about a repository's code live in the repository itself (its memory or rule files), never here.

| Pack | Trigger |
|---|---|
| [`contract-change`](packs/contract-change.md) | a slice changes a route, schema, tool, wire key, file format, or user-visible behaviour |
| [`rename`](packs/rename.md) | a slice removes or renames a name or value across the tree |
| [`generated-files`](packs/generated-files.md) | a slice regenerates a committed file |
| [`dependency-upgrade`](packs/dependency-upgrade.md) | a slice changes a lock file |
| [`stacked-prs`](packs/stacked-prs.md) | slices whose PRs build on each other |
| [`worktrees`](packs/worktrees.md) | the session is isolated in a worktree, or two slices commit at once |
| [`live-probe`](packs/live-probe.md) | a criterion or brief calls a live API, or a finding claims what a class accepts |
| [`measurement`](packs/measurement.md) | a criterion compares a number, or a slice adds telemetry |
| [`ci-failure`](packs/ci-failure.md) | a check fails on a slice's PR |

When you write a slice, match it against both indexes. Turn each matched pack into acceptance criteria and brief lines of that slice, and list the packs in its `Packs:` line. A brief carries only its slice's packs.

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
3. Write `plan.md`: the goal, out of scope, locked decisions, and every slice with its goal, out-of-scope list, acceptance criteria (a command and its expected result), the files or areas it touches, the slices it depends on, and its packs.
   - Each acceptance criterion is the command that produces the result where it will run, against the real artifact, never against a constant from the code.
   - Before approval, grep every symbol, file and test the plan names, and every claim that a mechanism is missing. Mark files the slice creates with `(new)`. A code-map line that states a rule cites the function or ADR that defines it.
4. Group the slices into waves: a wave holds slices with no dependency between them. In a wave of two or more, give every slice `isolation: worktree`, so each coder commits on its own branch; `slices-wave` refuses a wave that misses one.
5. Send `reviewer` the plan, not a diff, with two questions per slice: does a much simpler change reach the same goal, and does the slice fix the root cause of a need users have? Change the plan for each finding with a concrete case, and show the user the findings you rejected and why.
6. Rehearse the plan when it has three or more slices, or any acceptance criterion that runs a benchmark or an eval:
   - Run every acceptance criterion command now, on the base, where its slice will run it. Each one must run and fail for the expected reason, or print the baseline. A command that cannot run there (a missing stack, service, fixture or permission) changes the plan now, not mid-wave.
   - Send `explorer` once per slice for a pre-mortem: read the code the slice touches and list what would make its coder stop, such as an ambiguous contract, an unknown caller, a missing fixture or a choice between options. Settle each item in the plan, or turn it into a question for step 7.
   - Log the rehearsal result in `logbook.md`.
7. Show the user the slice table, the waves and every open question in one message, each question with its options and a recommendation, and wait for approval. Approval of the plan is approval to run its waves, open its PRs and decide inside the plan as "Decide or stop" says; nothing else is.
8. Copy the slice list into `loop.md` with status `todo`. Log the approval in `logbook.md`.

## status (also on "retoma", "cómo va", "qué falta")

1. Read `loop.md`, then run [`status.sh`](status.sh) `<loop dir>`: one line per PR linked in `loop.md` with its state, base, head, CI, review-bot score, open bot threads, mergeability and commits behind its base, then the number of signals without an outcome. Never answer from memory, and never rebuild this with ad-hoc `gh` calls.
   - CI is green only when every expected check has completed and passed on the head SHA. A pending, queued or missing check is not green. The same bar applies before a slice is marked `ready` or `done`. After a push or a rerun, wait until the expected checks appear before reading their state.
2. Update `loop.md` with what changed.
3. Answer with one table: slice | goal in plain words | status | evidence or blocker | PR link. Then the "Decided for you" rows added since the last status, and the next step.

## run `<wave>`

Run one slice inline (coder, then reviewer) when the wave has one slice. Run a wave of two or more through the saved workflow:

```
Workflow({ name: "slices-wave", args: { epic, repo_path, wave, slices: [ { id, goal, out_of_scope, acceptance: [{id, command, expected}], touches, isolation } ] } })
```

- When a slice starts, set it to `coding` in `loop.md`, and set its **Linear** ticket to In Progress with the Linear MCP.
- Two slices that run in parallel always run through `slices-wave`. Never hand-spawn parallel coders, and never fold a slice's own review into the PR review.
- Pass the slice blocks from `plan.md` verbatim, with their packs' lines. Record the run id in `loop.md` next to the wave; resume a broken wave with `resumeFromRunId`. If the named workflow is not found, pass `scriptPath: "~/code/dotfiles/config/claude/workflows/slices-wave.js"`.
- When it returns, check each slice's evidence yourself before you move it on: to `ship` when its **Ends in** line names a PR, otherwise to `done`. Check the AC commands and the reviewer's verdict line. Copy every `signals` entry into `signals.md` with the slice id, every `follow_ups` entry (the P2 findings left on a slice that shipped) into the "Follow-ups" table of `loop.md`, and every `decisions` entry as "Decide or stop" says. A slice run inline does the same with its reviewer's report. A slice that returned `stopped` hit a gate: report the gate and the coder's reason to the user.
- A slice that ended with `Verdict: fix ...` after 3 rounds is `blocked`. Report it to the user with the open findings; do not start a fourth round on your own.
- Every defect a brief states carries its evidence: a `file:symbol` citation of the code as it is on the base today, or the output of a probe that reproduces it.
- The coder commits its work (a WIP commit is fine) before the review starts, and names the SHA. The reviewer reviews in the coder's worktree at that SHA while the coder is stopped, and does not edit it. It creates a detached worktree (`git worktree add --detach <main checkout>/.claude/worktrees/review-<slice> <sha>`) only to mutate code to prove a finding, and removes it with `git worktree remove --force <path>` when the review ends.

## ship `<slice>`

Run it for each slice whose **Ends in** line names a PR, once its reviewer passed it and you checked its evidence. The user merges, unless the slice's **Merge** line says `auto`.

1. Push the slice's branch and open the PR against the base the repository's CLAUDE.md or CONTRIBUTING.md names. Use the repository's `pr` skill when it has one; otherwise run `gh pr create` with `--body-file`. With a **Linear** ticket, put its ID in the branch name and the PR body, so Linear's GitHub integration links them. The slice reviewer's pass is the review before the PR when the PR holds only this slice's commits. A PR that also holds other work gets a reviewer pass on its whole diff first. Link the PR in `loop.md` and set the status to `pr`.
2. Wait for CI with `status.sh`. Fix a red check on the slice's branch, with the repository's CI skill when it has one (`react-to-pipelines`). Send every fix that changes logic to the reviewer before its push.
3. With CI green, set the status to `bot-review`. Answer the review bot with the repository's skill for it when it has one (`react-to-greptile`). Send every bot-driven fix that changes logic to the reviewer before its push.
4. Set the status to `ready` when `status.sh` shows `READY yes`, and tell the user. Otherwise fix what its `no:` names. A 3/5 counts only when the user accepts it for that PR; log it in `logbook.md` as `decided:`.
5. With `Merge: auto` and `READY yes`, run `gh pr merge <n> --repo <repo> --merge --match-head-commit <full head SHA from `gh pr view <n> --json headRefOid`>`, then run `land`. In a stack, merge the bottom PR first, then run `status.sh` again for the next one. With `Merge: manual`, stop at `ready`.

## land `<slice>` (also on "mergeado", "merged")

Run it when the user says a slice's PR merged.

1. Run `status.sh` and check that the PR shows `merged`. If it does not, say so and stop.
2. Set the slice to `merged` in `loop.md` and log the merge commit in `logbook.md`. Check its **Linear** ticket: Linear's integration usually moves it to Done on merge; if it did not, set Done with the Linear MCP.
3. When the slice has its own worktree, stop its stack the way the repository's profile says, then remove the worktree and its local branch. Before you remove anything, check that `git status --porcelain` in the worktree prints nothing; if it prints anything, keep the worktree and report the files.
4. Name the next wave whose slices the merge unblocked, or say that the loop has only the retro left.

## retro

Run it as the last slice of every loop, and when the user asks.

1. Read `signals.md`, `logbook.md` and the "Follow-ups" table of `loop.md`.
2. Group the signals that repeat or that cost a round. Ignore the rest. Count the findings a reviewer reported late (on code unchanged since an earlier round) as a reviewer signal, and the vetoed "Decided for you" rows as signals against the decision rule.
3. Route each group by the first question it answers yes to:
   - Does it make sense for a slice in another repository? A generic pack, or this file only if every slice needs it.
   - Is it about this repository's code? The repository's own memory or rule files, through a PR.
   - Is it about how the user works in this repository? A pack in its profile.
   - Is it a need of the product? An issue, never a rule.
4. For each group, propose one concrete change: the file or the issue, the exact line, and the evidence (which signals, how many times).
   - First grep this file, the packs, the agent profiles and the repository's rules for a line that already covers it. If one does, the rule failed: replace it with a mechanism (a check in a script, a field in a template) or rewrite it, never add a second line.
   - Prefer a mechanism to a sentence. A new line replaces or merges an old one: this file and each pack do not grow.
   - A generic line names no module, route or format of this epic. Write every line in English, whatever language the conversation uses.
5. Set `Last used:` to this epic in every pack a slice of this loop loaded. Propose deleting a pack, or a line in it, that no slice loaded in the last three loops.
6. Show one table per destination: what happened (count) | proposed change | file or issue. Apply what the user approves and log the retro in `logbook.md`. Then give every signal you read an outcome at the end of its line: `[used]` when an approved change came from it, `[dup]` when another signal or an existing line already covers it, `[dropped: <why>]` otherwise. `status.sh` counts the signals left without one.
7. Show the follow-ups in a last table: finding | location | proposal (open an issue, or drop it and why). Open the issues the user approves and mark each row `issue <link>` or `dropped`.
