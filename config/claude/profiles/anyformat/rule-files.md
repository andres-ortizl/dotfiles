# Rule files for a path in the anyformat monorepo

Greptile enforces every rule in these files as must-fix. The coder reads them before writing code; the reviewer reads them before reading the diff.

1. Once per session: root `CLAUDE.md` and root `CONTRIBUTING.md`.
2. Before the first edit or review of a file in a new directory, walk from that directory up to the repo root and read, on the way:
   - every `.greptile/rules.md` (for example `anyformat/services/frontend/.greptile/rules.md`);
   - every `CONTRIBUTING.md` (for example `anyformat/services/frontend/CONTRIBUTING.md`);
   - the docs that a `.greptile/files.json` on that walk scopes to the path (for example `DESIGN.md` and `PRODUCT.md` for `frontend/src`).
3. Follow the trigger tables in root `CLAUDE.md` for the touched paths (for example `docs/memory/frontend/INDEX.md` for the frontend, the layer skill for a backend layer).
4. Read each file once per session. A backend-only change does not load frontend docs, and the reverse.

Greptile loads root `CLAUDE.md`, root `CONTRIBUTING.md` and the service `CONTRIBUTING.md` files from its dashboard, so `.greptile/` alone does not list them.
