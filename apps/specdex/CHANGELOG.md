# Changelog

All notable changes to specdex. Format loosely follows [Keep a Changelog](https://keepachangelog.com).

## [Unreleased]

### Added
- **Event substrate** — per-spec append-only `events.jsonl` + derived `state.json` under `~/.spec/<project>/<spec>/`. Vendor-agnostic, event-sourced (state is always derived).
- **`dex` CLI** — git-style resource-verb grammar with an ambient spec (`DEX_SPEC`): `init`, `phase`, `block`/`unblock`, `beat`, `agent spawn|idle`, `test`, `review`, `gate`, `pr`, `note`, `ls`, `watch`. Generic phases (`setup·plan·build·review·ship·verify·complete·accepted`) and derived health (`alive·idle·stale·needs-you·done`).
- **Config** — typed per-project `.dex.toml` (with optional global `~/.config/dex/config.toml`) on a `defaults ← global ← project` merge, a provider registry (role → provider, registry-resolved reactors), typed hooks, and `[[ports]]`. `dex config show|get|validate|schema`; `validate` warns when a referenced reactor/hook skill isn't installed.
- **`dex ports alloc`** — collision-aware port-offset allocation (skips reserved offsets and bind-busy ports), prints `export` lines.
- **`dex watch`** — streams the fleet snapshot as JSON, re-emitting on every registry change.
- **Desktop app** (`apps/desktop`, Tauri) — live fleet of "minion" cards (breathing life-dot, phase rail, agent pips, PR badge, `needs-you` ember), light/dark, watching `~/.spec` in real time. Zen visual system derived from drams.framer.
- **`/specdex` skill rewrite** (draft, `skill/`) — config-driven and vendor-agnostic: notifications route through the configured notifier, CI + bot-review collapsed into one `verify` phase using registry reactors, honors `phases_skip`, adds a `/specdex configure` mode.
- **README**.

### Known issues
- The minion life-dot breathes on `health == alive` rather than real recency, implying live activity when there is none (fix tracked in the roadmap).
