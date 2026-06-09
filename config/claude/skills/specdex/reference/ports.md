# Port assignment (Phase 0.5)

Ports are **config-driven and vendor-neutral** — the skill hardcodes no service names
or base ports. A project declares the services it runs in `.dex.toml`; a project that
runs nothing local (e.g. a CLI/library) declares none and this whole phase is skipped.

## Declare services in `.dex.toml`

```toml
[[ports]]
service = "frontend"
base    = 5173
env     = "VITE_PORT"     # the env var the allocated port exports as
[[ports]]
service = "backend"
base    = 8080
env     = "BACKEND_PORT"
```

## Allocate

```bash
eval "$(dex ports alloc)"
```

`dex ports alloc` picks the **lowest offset** (multiples of 10, starting at 10 — offset
0 is your own dev stack) such that:
- the offset isn't reserved by another active spec (read from the registry's `state.json`s), and
- every `base + offset` port is **actually free** (real bind-check — won't collide with a random running process).

It records a `ports.assigned` event (so the offset is reserved and the fleet view shows
the ports) and prints `export <ENV>=<port>` lines, which `eval` loads into the worktree
shell. Persist them into the worktree `.env` too if your stack reads from a file.

## URL / derived env (project-specific)

Any URLs derived from ports (`BASE_URL`, OAuth redirect, CORS origin, a baked
`VITE_BASE_URL`, etc.) are **project-specific** and belong in the project's own
`.spec-env` / `.env` template or a `configure` step — not in this skill. Reference the
allocated `$<ENV>` values when composing them. Remember Vite-style build-time vars need
a container rebuild to take effect.

## If `[ports]` is absent

No services declared → skip allocation entirely. `dex ports alloc` prints
`# no [ports] configured` and exits cleanly.
