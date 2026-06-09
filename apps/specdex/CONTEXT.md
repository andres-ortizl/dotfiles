# CONTEXT — specdex

Orientation for anyone (human or agent) picking up a task in this repo. Read this first;
it explains what specdex is, how the code is laid out, where things start, and how to
build/run/test.

## What specdex is

specdex visualizes **autonomous AI coding runs as a living fleet**. Each running spec is a
**minion** — a card carrying a lifecycle phase (`setup → plan → build → review → ship →
verify → complete → accepted`), a health state, and 0–2 working agents.

Two halves:

- **`dex`** — a small Rust CLI that records a structured, per-spec **event stream**
  (`events.jsonl`) and folds it into a derived snapshot (`state.json`). This is the
  substrate the loop writes to.
- **specdex desktop** — a Tauri app that reads that registry and renders the fleet +
  per-spec detail. Live-updating (filesystem watcher → webview).

The orchestration *behavior* (the plan→build→review→ship loop, notifications) lives in the
`/specdex` **skill** under `skill/`, not in the binaries — the binaries are the data plane.

## Workspace layout

Cargo workspace (`Cargo.toml`, resolver 2), three members:

| Path | Crate | Role |
|---|---|---|
| `crates/core` | `specdex-core` | The brain: config, event model, state-folding, paths, view models. No I/O policy beyond the registry. |
| `crates/cli` | `dex` (bin) | CLI over `core` — `dex init/phase/agent/test/review/pr/gate/beat/block/note/config/...`. |
| `apps/desktop` | `specdex-desktop` (bin) | Tauri app: Rust backend commands + a no-build vanilla web frontend. |
| `skill/` | — | The `/specdex` skill (markdown + references) that drives the loop. |

### `crates/core/src`
- `config.rs` — `.dex.toml` model. `Effective` = merged config; layered
  `defaults ← ~/.config/dex/config.toml ← <repo>/.dex.toml`. Providers (notifier/ci/
  pr_review/multiplexer) are validated against a `REGISTRY` (which also maps a provider →
  its reactor skill). `get_dotted` powers `dex config get <key>`; `schema()` powers
  `/specdex configure`.
- `event.rs` — the event vocabulary: `Event` (typed envelope) + `Payload` (the variants:
  phase enter, agent spawn/idle, test result, review verdict, gate status, pr, block,
  note, heartbeat, …) and the enums (`Phase`, `Role`, `Verdict`, `GateResult`, `PrState`, …).
- `state.rs` — `SpecState` snapshot + `apply(payload)` folding, and `Health` derivation
  (alive / idle / stale / needs-you / done).
- `view.rs` — `FleetRow` / `AgentView`: the trimmed shapes the desktop list renders.
- `paths.rs` — the registry layout: `~/.spec/<project>/<spec>/{events.jsonl, state.json,
  spec.md, logbook.md}`.
- `ports.rs` — port-offset allocation for specs that declare `[[ports]]`.
- `lib.rs` — the public API + the read/write helpers: `emit` (the one write path),
  `load_state`, `read_events`, `load_spec_doc`, `load_logbook`, `load_all`,
  `project_config` / `project_config_raw` (resolve a project's `.dex.toml` via one of its
  spec worktrees — merged `Effective`, or the raw file text).

### `apps/desktop`
- `src/main.rs` — Tauri entrypoint. Exposes the commands the webview invokes:
  `fleet()`, `spec_detail(project,name)` (state + events + `spec.md`/`logbook.md` + the
  project's raw `.dex.toml` as `config_raw`), `project_config(project)` (merged `Effective`,
  for the sidebar summary), and `attach_terminal(project,name)` (opens the configured
  terminal — default ghostty — attached to the spec's multiplexer session, via
  `std::process::Command`). A background thread watches `~/.spec` (the `notify` crate) and
  pushes a fresh `fleet` snapshot to the webview on change.
- `ui/` — the frontend, **served as-is, no build step** (`tauri.conf.json`
  `frontendDist: "ui"`):
  - `index.html` — shell (topbar, sidebar, fleet/detail panes).
  - `app.js` — all rendering + routing. Talks to Tauri via `window.__TAURI__.core.invoke`;
    when opened directly in a browser it falls back to hardcoded sample data, so the file
    doubles as a standalone prototype.
  - `style.css` — the design system in CSS custom properties.
  - `DESIGN.md` — the visual language (drams-derived, tactile/minimal). Read before any UI
    change. `drams-components.html` is the live component reference.

## Data model (the registry)

Everything lives under `~/.spec/<project>/<spec>/`:
- `events.jsonl` — append-only event log (source of truth).
- `state.json` — derived snapshot (fold of the events).
- `spec.md` — the approved plan. `logbook.md` — the human-readable timeline.

`dex` is the only writer (`emit` appends an event and rewrites the snapshot). The desktop
app and the global watcher are readers.

## Config (`.dex.toml`)

Repo-root `.dex.toml` is the primary config; an optional `~/.config/dex/config.toml`
provides personal defaults; built-in defaults are the base. Higher layer wins per field
(except `hooks`, which merge additively). Key tables: `[providers]`, `[hooks]`,
`[phases] skip=[...]`, `[[ports]]`, `[identity]`, `[models]`. Query with
`dex config get <dotted.key>`; inspect the option space with `dex config schema`.

This repo's own config: `notifier=slack`, `ci=none`, `pr_review=none`,
`phases_skip=["verify"]` — so its own specdex loop ends at the PR (no CI/bot phase).

## Build / run / test

```sh
cargo build                       # whole workspace
cargo test                        # all tests (core has the bulk; fast)
cargo test -p specdex-core        # just core (config/state/event/view)

cargo run -p dex -- <args>        # run the CLI, e.g. `cargo run -p dex -- config show`
cargo run -p specdex-desktop      # run the desktop app (or `cargo tauri dev`)
```

The frontend has **no build and no JS test harness** — edit `ui/*` and reload the app.
Rust changes require a rebuild. Keep the testable logic in `crates/core` (pure functions,
unit-tested) and keep `apps/desktop/src/main.rs` a thin shell over it.

## Conventions
- The skill names **no vendor** directly — providers/reactors resolve through the config
  `REGISTRY`. Add a provider there, not inline.
- New, testable behavior belongs in `core` with tests; the CLI and Tauri layers stay thin.
- UI changes follow `apps/desktop/ui/DESIGN.md` tokens (tactile, two surfaces, one accent).
