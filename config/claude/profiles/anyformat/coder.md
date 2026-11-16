# Personal profile: anyformat monorepo, coder

- Work only in the worktree path you were given. Bring a fresh worktree up with `./scripts/agent-prepare.sh` first.
- Before you edit a file in a new directory, read the rule files for that path, as `~/code/dotfiles/config/claude/profiles/anyformat/rule-files.md` lists them. Greptile enforces them as must-fix.
- Run tests where they can run, and choose what to run per change:
  - Where: domain, libs, engine and api run on the host: `cd anyformat/<pkg> && uv run pytest <path>`. Core runs on the host for tests that touch no S3, database or broker; run the rest of core, and its whole suite, in the container: the `make test-core` target's `compose up` once, then `docker compose run --rm --no-deps anyformat-core pytest <path>`. Backend always runs in the container (every test needs Postgres). A host run that fails with `InvalidAccessKeyId`, an S3 403 or a refused connection ran in the wrong place, not on broken code: rerun it in the container.
  - Scope: the narrowest path that proves the change while you iterate; the package's whole suite (its `make test-*` target, CONTRIBUTING.md -> Running Tests) before you report.
  - Markers (core `pytest.ini`): `llm` and `vlm` call the real model through the LLM proxy. They need the VPN, cost money, can be flaky, and CI never runs them. `slow` loads OCR models. `huge` costs dollars per run.
  - Choose: deselect `llm` by default. Run the `llm` tests of the touched path when the change alters what the model sees or returns (a prompt, a schema, the parsing of an answer), and report what they showed. Ask before `huge` or a whole `llm` suite.
  - Failure symptoms and their fixes: `docs/memory/testing.md`.
- Python lint is `ruff check --fix` plus the `ruff-strict` hook on touched files. Never run `ruff format` on this repo.
- Change a decision in an accepted ADR with a new ADR that `amends` it, through the `writing-an-adr` skill. Never edit the accepted decision in place.
- A comment or docstring is a short why, two lines at most. Greptile blocks longer ones. A longer reasoning goes to an ADR.
- Test identity fields use real UUIDs (`uuid4().hex`, builder ids, or the shared `UUID_1`/`UUID_2` constants), never "user-1".
- Single-kind spatial JSONB uses the flat shape `{"x0", "y0", "x1", "y1"}`. A second kind gets a sibling column, not a nested key.
- Never `git stash` in this repo's worktrees (uv rewrites `uv.lock`); never run a git command while pre-commit hooks run.
- Before changing visible text or a `data-testid` on a screen, grep `anyformat/services/frontend/playwright/e2e/` for those strings. Treat every match as a fixed constraint.
- An accepted shortcut gets `# deferred: <the limit>, <when to revisit>` so the reviewer and Greptile treat it as a decision.
- Never skip a blocking hook as "pre-existing": CI runs `ast-grep-shape` and `ruff-strict` on every file in the PR diff. Before the PR, run each on the files of `git diff --name-only origin/dev...HEAD`.
