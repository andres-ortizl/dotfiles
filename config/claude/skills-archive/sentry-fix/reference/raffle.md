# Reviewer raffle

When a dispatched spec loop posts its `:mag: Ready for review` message to `#tech`, tag a reviewer picked at random from `SENTRY_REVIEWERS`.

```bash
# For each PR, pick one entry and destructure it:
python3 -c "
import random, os
pool = [r.split(':') for r in os.environ['SENTRY_REVIEWERS'].split(',')]
name, slack_id, gh_handle = random.choice(pool)
print(f'{name} {slack_id} {gh_handle}')
"
```

Do NOT seed the random — truly random is fine per the user's instruction. The spec skill is responsible for posting the reviewer message; sentry-fix just supplies the rotation list in the dispatch args.

Reviewer raffle runs **once per PR** — each PR is independent work and spreading review load matters more than batching. For every PR, pick uniformly at random. Duplicates across PRs are allowed (it's a raffle, not a round-robin).

## Self-nomination rule

If the raffle picks someone who is the GH author of that specific PR (check `gh pr view <n> --json author --jq .author.login` against the reviewer's GH handle), **re-roll that single PR once**. A person reviewing their own PR adds nothing.

## Author-runs-raffle collapse

When the human running `/sentry-fix` happens to be the GH author of every dispatched PR — which is normal when the `claude -p` sub-sessions commit under the runner's git identity — the naive re-roll rule would eliminate the entire pool on the first spin. Handle it explicitly:

1. Before raffling, identify the runner's GH handle: `gh api user --jq .login`.
2. If the runner's handle matches the author of **every** dispatched PR, remove the runner from the raffle pool entirely for this cycle (not just for their own PR — from all PRs). The raffle becomes `pool - {runner}`.
3. Log this in the run header: "Author-runs-raffle collapse detected; excluding <runner> from pool for this cycle."

This is not cheating — it recognises that an author reviewing their own work is worthless and avoids the degenerate case.

## GH reviewer assignment — self-review fallback

`gh pr edit <n> --add-reviewer <handle>` silently drops self-nominations. It returns the PR URL with no error but the reviewer is never set. If the raffle picks the author (e.g. when the user overrides the raffle manually per the "cheat a bit" pattern), use `--add-assignee` instead:

```bash
gh pr edit <n> --add-assignee <gh_handle>
```

Assignees show up in a different UI lane than review requests, but the author can find their own PRs from the assignee filter and it's a visible signal. When both `--add-reviewer` and `--add-assignee` would be self-assignment, skip the GH field entirely and rely on the Slack tag alone.
