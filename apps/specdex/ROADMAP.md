# Roadmap

specdex is built in chunks — each a self-contained, shippable slice.

## Shipped

- **1 · Substrate** — vendor-agnostic, event-sourced core (`events.jsonl` + derived `state.json`) and the `dex` CLI.
- **2 · Config + vaults** — typed `.dex.toml`, the `defaults ← vault ← project` merge, provider registry, `dex config`.
- **3 · Config-driven `/specdex`** — the skill rewired to read config and name no vendor; CI + bot-review collapsed into one `verify` phase; `/specdex configure`. Generalized ports (`dex ports alloc`).
- **4 · Desktop fleet** — the Tauri app: live "minion" cards in a zen visual system, watching `~/.spec` in real time.
- **5 · Docs** — README, changelog, roadmap. *(logo via nano-banana — in progress)*

## Next

- **6 · Screens & spec-detail** — in-app navigation + a **detail view per spec**: the event timeline (from `events.jsonl`), live state, and the agents working on it. Includes the **life-dot truthfulness fix** (motion tracks real recency, not the health label).
- **7 · Config & Signals screens** — an in-app config view (`.dex.toml` / vaults / validate / configure) and **Signals**: the global `note` feed — skill-feedback and env-failures aggregated across the whole fleet (the "watcher").
- **8 · World** — a second, playful mode: agents as pixel characters in a cozy top-down office (à la "Pixel Agents"). Ambient delight alongside the zen fleet — same agents, two fidelities.

## Threaded (small, any time)

- **spec ↔ PR link** — stamp `Spec: <project>/<name>` into the PR body at ship (the spec id already exists; no substrate change).
- **`session_jsonl` on `agent.spawn`** — link agents to their Claude session transcript; unlocks tool-by-tool liveness and an in-app transcript view.
- Backfill `state.json` for pre-substrate specs; retire the superseded `agentdex` / `spec-dashboard` prototypes.

## Principles

- **Visualize vs. intervene** — the app shows the story; the terminal stays where you act.
- **The substrate names no vendor** — tools live in config, not core.
- **Don't lie** — motion and color mean what they say (the life-dot fix).
