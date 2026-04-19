# Stage B: Fix (K=3, bounded parallelism)

For each auto-dispatchable issue:

## 1. Write the plan file

Write to `~/.spec/<project-name>/sentry-fix-<issue-id>/plan.md` using the Stage A report as the source. The plan file MUST include:

- `## Sentry metadata` — `sentry_issue_id: <id>`, `sentry_url: <url>`, all `duplicate_ids: [...]` from the cluster, event count, env (so reconcile can resolve every member)
- `## Context` — the Sentry issue details (title, error, frequency, first/last seen, stack trace excerpt)
- `## Root cause` — from the triage agent
- `## Files to modify` — from `files_to_touch`
- `## Implementation` — from `proposed_fix`
- `## Acceptance criteria` — at minimum:
  - [ ] Repro test reproduces the original Sentry error
  - [ ] Fix makes the repro test pass
  - [ ] No regression in affected module's test suite
- `## Verification` — how to run the affected tests
- `## Branch` — `sentry-fix/<issue-id>`

## 2. Dispatch pattern: zellij pane per issue (NOT `Skill(spec)` inline)

**Do NOT invoke `Skill(spec, "--auto-approve ...")` from the sentry-fix main context.** It reads as a parallel fan-out in the skill prose, but it does not actually parallelize — each Skill tool call takes over the main turn and can't schedule wakeups across turn boundaries, so you get one sequential loop and no CI watching. This has been tried and fails.

**Correct pattern:** spawn each spec loop as its own interactive `claude` session inside its own Zellij pane. Each pane is an isolated lead context that runs the full spec skill end-to-end (implement → reviewer loop → /pr → CI watch → Greptile rounds) with its own ScheduleWakeup budget and its own logbook.

For each auto-dispatchable issue:

```bash
# 1. Create the worktree up front (spec skill expects to be inside one)
git worktree add \
  /Users/andrew/code/<project-name>/.claude/worktrees/sentry-fix-<issue-id> \
  -b sentry-fix/<issue-id> dev

# 2. Spawn a fresh zellij tab running an interactive claude session in that worktree.
#    The initial prompt is `/spec --auto-approve <plan-path>` so the full 5-phase
#    spec flow runs inside the sub-session with its own context budget.
zellij action new-tab --name "sentry-fix-<issue-id>" --cwd \
  /Users/andrew/code/<project-name>/.claude/worktrees/sentry-fix-<issue-id>
zellij action write-chars \
  "claude --dangerously-skip-permissions \"/spec --auto-approve /Users/andrew/.spec/<project-name>/sentry-fix-<issue-id>/plan.md\""
zellij action write 13   # Enter
```

If `zellij action new-tab` / `write-chars` isn't available in the environment (e.g. running under tmux), fall back to:

```bash
tmux new-window -n "sentry-fix-<issue-id>" -c <worktree-path> \
  "claude --dangerously-skip-permissions '/spec --auto-approve <plan-path>'"
```

## 3. PR labeling (required)

Every PR opened by a sentry-fix dispatch MUST carry the `sentry` label on creation, so the GH PR list can be filtered to just Sentry-originated work. The plan file's `## Implementation` section should instruct the sub-session to create the PR with:

```bash
gh pr create --base dev \
  --title "<conventional commit> [<SHORT-ID>]" \
  --label sentry \
  --body "..."
```

If the label doesn't exist yet in the repo, the first run of sentry-fix creates it once (`gh label create sentry --description "PR fixes a Sentry issue (auto-applied by /sentry-fix)" --color "D93F0B"`), then applies it. Subsequent PRs reuse it.

Retroactive fix: if a sub-session forgot the label flag (old plan file, manual `-p` shortcut, etc.), add it after the fact with `gh pr edit <number> --add-label sentry`.

**`claude -p` is NOT a replacement for a zellij pane.** It was used once in early iterations and shipped working PRs for trivial fixes (1-line type adds, try/except wrappers, SQL quoting), but it runs a single turn — so it skips Phase 3 (reviewer loop), Phase 4b (CI watch), and Phase 5 (Greptile rounds + `/react-to-greptile`). Only use `-p` as a manual shortcut for **scope-S mechanical fixes with regression tests**, and only when you explicitly accept losing the review/Greptile gate. The default dispatch path is the interactive zellij pane above.

## 4. Bounded parallelism

- **K=3** is still the cap. Three pane tabs per run, no more. Tabs that outlive the main sentry-fix session keep running — they're owned by their own leads now.
- **Branch naming**: `sentry-fix/<issue-id>`. Reconcile (Stage -1) pattern-matches on the `sentry` label, not the branch prefix — but keep the prefix for human readability.
- **Do NOT wait synchronously** for the panes to complete. Back in the sentry-fix main context, use `ScheduleWakeup` (delay 1200s / 20min) to poll `gh pr list --head "sentry-fix/*"` for newly-created PRs. The sub-session leads post their own DMs at each phase; sentry-fix only owns the `#tech` cycle messages.

## Reviewer rotation

See `raffle.md` for the raffle logic. Dispatched spec loops post their `:mag: Ready for review` to `#tech`, and the raffle runs once per PR once Greptile 5/5 + CI green.
