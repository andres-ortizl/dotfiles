# Port and project name assignment (Phase 0.5)

Find the lowest available port offset by checking which offsets are in use by active specs across ALL projects:

1. Read every `~/.spec/*/*/logbook.md` — if status is NOT `COMPLETE`, that spec is active
2. Read every active spec's `env.md` to find its offset (derive from any port, e.g., `BACKEND_PORT - 8080`)
3. Pick the lowest multiple of 10 (starting at 10) not used by any active spec

Offset 0 is reserved for the user's own dev stack (default ports).

```
offset = lowest unused multiple of 10, starting at 10
```

## Append to the worktree's `.env`

```env
COMPOSE_PROJECT_NAME=spec-<spec-name>
FRONTEND_PORT=$((5173 + offset))
BACKEND_PORT=$((8080 + offset))
API_PORT=$((8081 + offset))
POSTGRES_PORT=$((5432 + offset))
```

## Log the assigned ports

Write `~/.spec/<project-name>/<spec-name>/env.md`:

```markdown
# Environment: <spec-name>

Worktree: .claude/worktrees/spec/<spec-name>
Branch: spec/<spec-name>
COMPOSE_PROJECT_NAME: spec-<spec-name>

| Service   | Port  |
|-----------|-------|
| Frontend  | <port> |
| Backend   | <port> |
| API       | <port> |
| Postgres  | <port> |
```
