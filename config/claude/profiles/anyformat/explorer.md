# Personal profile: anyformat monorepo, explorer

- Tests live in `anyformat/services/<svc>/tests/`, a sibling of the package; evals, `scripts/` and `spikes/` sit outside it too. Grep for importers and callers from the repo root.
- Search from the repository root of the worktree you were given, never from the main checkout under `~/code/anyformat-backend` unless that is the path you were given.
- Before reconstructing how something works, check the repo's own maps: the trigger tables in `CLAUDE.md` point to `docs/how-it-works/`, `docs/memory/` and `docs/adr/`. Cite the page you used.
