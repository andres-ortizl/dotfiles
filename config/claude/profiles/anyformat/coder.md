# Personal profile: anyformat monorepo, coder

- Work only in the worktree path you were given. Bring a fresh worktree up with `./scripts/agent-prepare.sh` first.
- Before you edit a file in a new directory, read the rule files for that path, as `~/code/dotfiles/config/claude/profiles/anyformat/rule-files.md` lists them. Greptile enforces them as must-fix.
- Run tests with the `run-tests` skill or the exact command in the slice's acceptance criteria. Default suite only: no `-m llm`, no `-m slow`.
- Python lint is `ruff check --fix` plus the `ruff-strict` hook on touched files. Never run `ruff format` on this repo.
- A comment or docstring is a short why, two lines at most. Greptile blocks longer ones. A longer reasoning goes to an ADR.
- Test identity fields use real UUIDs (`uuid4().hex`, builder ids, or the shared `UUID_1`/`UUID_2` constants), never "user-1".
- Single-kind spatial JSONB uses the flat shape `{"x0", "y0", "x1", "y1"}`. A second kind gets a sibling column, not a nested key.
- Never `git stash` in this repo's worktrees (uv rewrites `uv.lock`); never run a git command while pre-commit hooks run.
- Before changing visible text or a `data-testid` on a screen, grep `anyformat/services/frontend/playwright/e2e/` for those strings. Treat every match as a fixed constraint.
- An accepted shortcut gets `# deferred: <the limit>, <when to revisit>` so the reviewer and Greptile treat it as a decision.
