# Personal profile: anyformat monorepo, main agent

These rules add to the repo's CLAUDE.md. They are Andrew's, not the team's.

## Branches, PRs and pushes
- Branch from `origin/dev` and open PRs against `dev`. `main` is production; only `/prod-release` targets it.
- Before extending a branch, run `git rev-list --left-right --count origin/dev...HEAD`. More than about 50 behind: merge dev in and re-check the patterns you rely on first.
- Before every push to an open PR: `git fetch origin dev && git merge-tree --write-tree --name-only HEAD origin/dev`. For a stacked PR, `git rebase --onto <new-base> <old-base-tip>`.
- Address Greptile with the `react-to-greptile` skill.
- Never push to `~/code/devops` main without a fresh, explicit yes on the prepared diff. An earlier deferral is not consent, and red CI is not authority.
- Create only one side of a Linear/GitHub issue pair, preferably Linear (`save_issue`). Never also run `gh issue create`: the sync mirrors it.

## Worktrees and the local stack
- Bring up every fresh worktree with `./scripts/agent-prepare.sh` before anything else. Do not re-run it mid-session: it overwrites `.env` edits.
- `cd` into the worktree's nested path (`.claude/worktrees/<name>/...`), never the main checkout, which runs against dev.
- Give every subagent the absolute worktree path in every command, and have it check that `docker compose port backend 8080` matches the worktree's port. A subagent's working directory defaults to the main checkout.
- Do not create a branch mid-session in a worktree: the compose project name follows the branch and the first stack is orphaned.
- Never `git stash` in a uv worktree: `uv run` rewrites `uv.lock` and the pop aborts with your edits stuck in the stash. Compare against base with `git show <base>:<path>` or a separate worktree.
- Run one pytest runner per compose stack at a time. `UndefinedTable` or "database is being accessed by other users" means contention, not a regression.
- Never run `docker compose up -d --force-recreate` without a service name while runs are in flight: it recreates rabbitmq and loses the queue. Check `rabbitmqctl list_queues name messages messages_unacknowledged` first.
- Run no git command in the worktree while pre-commit hooks run (index lock). If the TypeScript hook is OOM-killed, retry the commit.
- Compose tests bind-mount the live tree. To verify a commit, test in a throwaway worktree at that exact SHA.

## Product and tooling facts that change decisions
- Internal-agent evals (Anniebal, Cristina, the pi coder) hold the model at GLM-5.3. Do not propose Claude models as an arm or fallback; vary harness, plugins and environment.
- Before adding frontend telemetry, confirm billing: Datadog has no browser APM, RUM is a separately billed SKU, and Sentry already runs on the frontend.

## Slices
- Acceptance criteria use the repo's own commands (`/run-tests`, `uv run pytest <path>`, `npm run test:ts`), never a hand-written approximation.
